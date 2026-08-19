#!/usr/bin/env bash
# Demo 05 — Create an AMI from the bootc image and deploy it to a real EC2 VM.
# Consumption mode: cloud disk image -> running cloud host OS, one toolchain.
#
# All AWS values come from common/env (nothing hardcoded). Real credentials
# live in ~/.aws. This creates billable AWS resources — see `cleanup`.
#
#   ./run.sh build-ami    build + register the AMI via bootc-image-builder
#   ./run.sh launch       launch an EC2 instance from the AMI and print its IP
#   ./run.sh ssh          SSH into the instance as the baked demo user
#   ./run.sh all          build-ami + launch (default)
#   ./run.sh cleanup      terminate instance, deregister AMI, delete snapshot
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$ROOT/common/lib.sh"
load_env || true

IMAGE_NAME="${IMAGE_NAME:-bootc-demo}"
LOCAL_TAG="localhost/${IMAGE_NAME}:v1"
AMI_ARCH="${AMI_ARCH:-amd64}"
AMI_NAME="${IMAGE_NAME}-${AMI_ARCH}-v1"
INSTANCE_TAG="bootc-demo-05"
KEYDIR="$HERE/.demo-keys"
STATE="$HERE/.instance-id"
DEMO_USER="demo"

_aws() { aws --profile "${AWS_PROFILE:-default}" --region "${AWS_REGION:?}" "$@"; }

_ensure_keys() {
  mkdir -p "$KEYDIR"; chmod 700 "$KEYDIR"
  if [ ! -f "$KEYDIR/id_ed25519" ]; then
    log "generating demo SSH keypair in $KEYDIR"
    ssh-keygen -t ed25519 -N '' -C "bootc-demo-05" -f "$KEYDIR/id_ed25519" >/dev/null
  fi
}

cmd_build_ami() {
  require_cmd podman aws ssh-keygen
  require_env AWS_REGION S3_BUCKET
  podman image exists "$LOCAL_TAG" \
    || die "$LOCAL_TAG not found — run demos/01-create-bootc-container first"
  _ensure_keys

  # Render bib build config with our baked login user (base image has no default
  # user AND no cloud-init, so EC2 key-pair injection would NOT work — we bake it).
  local cfg="$HERE/config.toml"
  sed -e "s|__USERNAME__|$DEMO_USER|" \
      -e "s|__PASSWORD__|demo|" \
      -e "s|__SSHKEY__|$(cat "$KEYDIR/id_ed25519.pub")|" \
      "$ROOT/common/config.toml.tmpl" > "$cfg"
  ok "wrote $cfg (user=$DEMO_USER)"

  log "Building + registering AMI '$AMI_NAME' (arch=$AMI_ARCH, region=$AWS_REGION)"
  warn "this uploads a disk to s3://$S3_BUCKET and registers an AMI — billable"
  sudo podman run --rm -it \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v "$cfg":/config.toml:ro \
    -v "$HOME/.aws":/root/.aws:ro \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    --env "AWS_PROFILE=${AWS_PROFILE:-default}" \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type ami \
    --target-arch "$AMI_ARCH" \
    --aws-ami-name "$AMI_NAME" \
    --aws-bucket "$S3_BUCKET" \
    --aws-region "$AWS_REGION" \
    "$LOCAL_TAG"

  local ami_id; ami_id="$(_aws ec2 describe-images --owners self \
     --filters "Name=name,Values=$AMI_NAME" --query 'Images[0].ImageId' --output text)"
  [ -n "$ami_id" ] && [ "$ami_id" != "None" ] || die "AMI '$AMI_NAME' not found after build"
  ok "AMI registered: $ami_id"
  echo "$ami_id" > "$HERE/.ami-id"
}

cmd_launch() {
  require_cmd aws
  require_env AWS_REGION INSTANCE_TYPE
  local ami_id; ami_id="$(cat "$HERE/.ami-id" 2>/dev/null || true)"
  [ -n "$ami_id" ] || die "no AMI id on record — run ./run.sh build-ami first"

  local extra=()
  [ -n "${EC2_KEY_NAME:-}" ]        && extra+=(--key-name "$EC2_KEY_NAME")
  [ -n "${EC2_SECURITY_GROUP:-}" ]  && extra+=(--security-group-ids "$EC2_SECURITY_GROUP")
  [ -n "${EC2_SUBNET_ID:-}" ]       && extra+=(--subnet-id "$EC2_SUBNET_ID")

  log "Launching $INSTANCE_TYPE from $ami_id"
  local iid; iid="$(_aws ec2 run-instances \
      --image-id "$ami_id" \
      --instance-type "$INSTANCE_TYPE" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_TAG}]" \
      "${extra[@]}" \
      --query 'Instances[0].InstanceId' --output text)"
  [ -n "$iid" ] || die "run-instances failed"
  echo "$iid" > "$STATE"
  ok "instance: $iid — waiting for it to run"
  _aws ec2 wait instance-running --instance-ids "$iid"
  local ip; ip="$(_aws ec2 describe-instances --instance-ids "$iid" \
      --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
  echo "$ip" > "$HERE/.instance-ip"
  ok "public IP: $ip"
  log "SSH will work once the OS finishes first boot:  ./run.sh ssh"
  warn "ensure the instance's security group allows inbound TCP 22 from your IP"
}

cmd_ssh() {
  local ip; ip="$(cat "$HERE/.instance-ip" 2>/dev/null || true)"
  [ -n "$ip" ] || die "no instance IP on record — run ./run.sh launch first"
  _ensure_keys
  wait_for_ssh "$ip" "$DEMO_USER" 22 40
  log "Inside: bootc status ; systemctl status httpd ; cat /usr/share/bootc-demo-version"
  exec ssh -o StrictHostKeyChecking=no -i "$KEYDIR/id_ed25519" "${DEMO_USER}@${ip}"
}

cmd_cleanup() {
  require_cmd aws
  local iid ami_id
  iid="$(cat "$STATE" 2>/dev/null || true)"
  ami_id="$(cat "$HERE/.ami-id" 2>/dev/null || true)"
  if [ -n "$iid" ]; then
    log "terminating instance $iid"
    _aws ec2 terminate-instances --instance-ids "$iid" >/dev/null || true
    _aws ec2 wait instance-terminated --instance-ids "$iid" 2>/dev/null || true
    rm -f "$STATE" "$HERE/.instance-ip"
  fi
  if [ -n "$ami_id" ]; then
    local snap; snap="$(_aws ec2 describe-images --image-ids "$ami_id" \
       --query 'Images[0].BlockDeviceMappings[0].Ebs.SnapshotId' --output text 2>/dev/null || true)"
    log "deregistering AMI $ami_id"
    _aws ec2 deregister-image --image-id "$ami_id" >/dev/null 2>&1 || true
    if [ -n "$snap" ] && [ "$snap" != "None" ]; then
      log "deleting snapshot $snap"
      _aws ec2 delete-snapshot --snapshot-id "$snap" >/dev/null 2>&1 || true
    fi
    rm -f "$HERE/.ami-id"
  fi
  rm -f "$HERE/config.toml"
  warn "S3 staging objects in s3://${S3_BUCKET:-<bucket>} (if any) are not auto-deleted"
  ok "cleaned up"
}

case "${1:-all}" in
  build-ami) cmd_build_ami ;;
  launch)    cmd_launch ;;
  ssh)       cmd_ssh ;;
  all)       cmd_build_ami; cmd_launch ;;
  cleanup)   cmd_cleanup ;;
  *) die "usage: $0 [build-ami|launch|ssh|all|cleanup]" ;;
esac
