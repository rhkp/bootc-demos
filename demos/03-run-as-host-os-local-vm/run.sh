#!/usr/bin/env bash
# Demo 03 — Boot the bootc image as a host OS in a local VM, using bcvk.
# This is the "Installing in a VM" mode: the image boots its OWN kernel with
# systemd as the host's PID 1 (not a container namespace).
#
#   ./run.sh check         verify KVM + bcvk are available
#   ./run.sh ephemeral     throwaway VM, auto-SSH, terminates on logout (default)
#   ./run.sh libvirt       persistent named VM via libvirt
#   ./run.sh ssh           SSH into the persistent libvirt VM
#   ./run.sh cleanup       remove the persistent VM and the overlay image
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$ROOT/common/lib.sh"
load_env || true

IMAGE_NAME="${IMAGE_NAME:-bootc-demo}"
BASE_TAG="localhost/${IMAGE_NAME}:v1"
BCVK_TAG="localhost/${IMAGE_NAME}:v1-bcvk"
VM_NAME="bootc-demo-03"

cmd_check() {
  local ok=1
  command -v bcvk >/dev/null 2>&1 || { warn "bcvk not installed (dnf install bcvk)"; ok=0; }
  command -v podman >/dev/null 2>&1 || { warn "podman not installed"; ok=0; }
  if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    ok "/dev/kvm present and accessible"
  else
    warn "/dev/kvm missing or inaccessible — this demo needs KVM/nested virt."
    warn "On AWS: use a nested-virt-capable Intel instance (c7i/m7i/… with"
    warn "  NestedVirtualization=enabled) or a *.metal instance; or skip to demo 05."
    warn "Also ensure your user is in the 'kvm' group: sudo usermod -aG kvm \$USER (re-login)."
    ok=0
  fi

  # Rootless bcvk runs QEMU inside a podman container, which needs the host 'kvm'
  # supplementary group preserved via the keep-groups annotation — otherwise the
  # containerized QEMU can't open /dev/kvm even when the host user can ("KVM
  # device not accessible").
  if grep -rqs 'keep_original_groups' \
        "$HOME/.config/containers/containers.conf" \
        /etc/containers/containers.conf /etc/containers/containers.conf.d 2>/dev/null; then
    ok "rootless keep-groups annotation is configured"
  else
    warn "rootless podman may not pass the 'kvm' group into containers."
    warn "If bcvk reports 'KVM device not accessible', add to"
    warn "  ~/.config/containers/containers.conf :"
    warn '    [containers]'
    warn '    annotations = ["run.oci.keep_original_groups=1"]'
  fi

  [ "$ok" -eq 1 ] && ok "environment looks good" || die "environment not ready (see warnings)"
}

_build_overlay() {
  require_cmd podman
  podman image exists "$BASE_TAG" \
    || die "$BASE_TAG not found — run demos/01-create-bootc-container first"
  log "Building bcvk-ready overlay $BCVK_TAG"
  podman build --build-arg "FROM_IMAGE=$BASE_TAG" -f "$HERE/Containerfile" -t "$BCVK_TAG" "$HERE"
}

cmd_ephemeral() {
  cmd_check
  _build_overlay
  log "Launching ephemeral VM and opening SSH (exit the shell to tear it down)"
  log "Inside the VM, try:  bootc status   |   systemctl status httpd   |   uname -r"
  bcvk ephemeral run-ssh "$BCVK_TAG"
}

cmd_libvirt() {
  cmd_check
  require_cmd bcvk
  _build_overlay
  log "Creating persistent libvirt VM '$VM_NAME'"
  bcvk libvirt run --name "$VM_NAME" "$BCVK_TAG"
  ok "VM '$VM_NAME' created. SSH with: ./run.sh ssh"
}

cmd_ssh()   { require_cmd bcvk; bcvk libvirt ssh "$VM_NAME"; }

cmd_cleanup() {
  log "Removing persistent VM '$VM_NAME' (if any)"
  bcvk libvirt rm -f "$VM_NAME" 2>/dev/null || true
  log "Removing overlay image $BCVK_TAG"
  podman rmi -f "$BCVK_TAG" 2>/dev/null || true
  ok "cleaned up"
}

case "${1:-ephemeral}" in
  check)     cmd_check ;;
  ephemeral) cmd_ephemeral ;;
  libvirt)   cmd_libvirt ;;
  ssh)       cmd_ssh ;;
  cleanup)   cmd_cleanup ;;
  *) die "usage: $0 [check|ephemeral|libvirt|ssh|cleanup]" ;;
esac
