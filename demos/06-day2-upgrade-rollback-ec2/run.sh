#!/usr/bin/env bash
# Demo 06 — Atomic upgrade + rollback on the running EC2 bootc host (demo 05).
# Consumption mode: day-2 lifecycle — bootc upgrade / rollback, digest-pinned.
#
# Build/push run on the dev VM; the bootc commands run ON the EC2 host over SSH
# (reusing demo 05's instance IP + baked demo key).
#
#   ./run.sh push-v1     build v1 and push to $REGISTRY (tags :v1 and :latest)
#   ./run.sh adopt       switch the EC2 host to TRACK the registry image (v1)
#   ./run.sh push-v2     build v2 and push to $REGISTRY (tags :v2 and :latest)
#   ./run.sh upgrade     bootc upgrade --apply on the EC2 host (-> v2)
#   ./run.sh status      show bootc status + served page on the EC2 host
#   ./run.sh rollback    bootc rollback --apply on the EC2 host (-> v1)
#   ./run.sh all         push-v1 -> adopt -> push-v2 -> upgrade -> status -> rollback -> status
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/common/lib.sh"
load_env || true

IMAGE_NAME="${IMAGE_NAME:-bootc-demo}"
REGISTRY="${REGISTRY:?set REGISTRY in common/env (e.g. quay.io/you or ghcr.io/you)}"
REG_IMAGE="${REGISTRY}/${IMAGE_NAME}"
CONTAINERFILE="$ROOT/common/Containerfile.base"

# EC2 target comes from demo 05's recorded state.
D05="$ROOT/demos/05-create-ami-deploy-ec2"
DEMO_USER="demo"
KEY="$D05/.demo-keys/id_ed25519"

_ec2_ip() { cat "$D05/.instance-ip" 2>/dev/null || die "no EC2 IP — run demo 05 (launch) first"; }
_ssh() { ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -i "$KEY" "${DEMO_USER}@$(_ec2_ip)" "$@"; }
_wait() { wait_for_ssh "$(_ec2_ip)" "$DEMO_USER" 22 60 "$KEY"; }

_build_push() { # _build_push VERSION
  require_cmd podman
  local v="$1"
  log "Building $REG_IMAGE:$v"
  podman build --build-arg "BASE=${BASE_IMAGE:-quay.io/centos-bootc/centos-bootc:stream10}" \
               --build-arg "VERSION=$v" -f "$CONTAINERFILE" \
               -t "$REG_IMAGE:$v" -t "$REG_IMAGE:latest" "$ROOT/common"
  log "Pushing $REG_IMAGE:$v and :latest  (log in first if needed: podman login $REGISTRY)"
  podman push "$REG_IMAGE:$v"
  podman push "$REG_IMAGE:latest"
  ok "pushed $v"
}

cmd_push_v1() { _build_push v1; }
cmd_push_v2() { _build_push v2; }

cmd_adopt() {
  _wait
  log "Pointing the EC2 host at the registry image and disabling auto-updates"
  # Disable the auto-update timer so it can't silently undo our manual rollback.
  _ssh 'sudo systemctl disable --now bootc-fetch-apply-updates.timer 2>/dev/null || true'
  # Switch from the AMI's local image ref to TRACKING the registry tag (still v1).
  # --apply reboots into the newly-tracked image.
  _ssh "sudo bootc switch --apply ${REG_IMAGE}:latest" || true
  log "host is rebooting to adopt the registry image ..."
  sleep 20; _wait
  cmd_status
}

cmd_upgrade() {
  _wait
  log "Checking for an update (metadata only):"
  _ssh 'sudo bootc upgrade --check' || true
  log "Applying upgrade (stages new digest, then reboots):"
  _ssh 'sudo bootc upgrade --apply' || true
  log "host is rebooting into the upgrade ..."
  sleep 20; _wait
  cmd_status
}

cmd_rollback() {
  _wait
  log "Rolling back to the previous deployment (reboots):"
  _ssh 'sudo bootc rollback --apply' || true
  log "host is rebooting into the rollback ..."
  sleep 20; _wait
  cmd_status
}

cmd_status() {
  _wait
  echo; log "bootc status on the EC2 host:"
  _ssh 'sudo bootc status | sed "s/^/  /"' || true
  echo; log "version stamp + served page:"
  _ssh 'echo "  version: $(cat /usr/share/bootc-demo-version)"; curl -fsS http://localhost/ | sed "s/^/  /" || true'
  echo
}

cmd_all() {
  cmd_push_v1
  cmd_adopt        # EC2 now tracks + runs v1 from the registry
  cmd_push_v2
  cmd_upgrade      # -> v2
  warn "above should show v2; now demonstrating rollback"
  cmd_rollback     # -> v1
  ok "lifecycle complete: v1 -> upgrade -> v2 -> rollback -> v1"
}

case "${1:-all}" in
  push-v1)  cmd_push_v1 ;;
  push-v2)  cmd_push_v2 ;;
  adopt)    cmd_adopt ;;
  upgrade)  cmd_upgrade ;;
  rollback) cmd_rollback ;;
  status)   cmd_status ;;
  all)      cmd_all ;;
  *) die "usage: $0 [push-v1|adopt|push-v2|upgrade|rollback|status|all]" ;;
esac
