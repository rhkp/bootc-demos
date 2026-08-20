#!/usr/bin/env bash
# Demo 04 — Podman Desktop bootc workflow (macOS, GUI).
# This demo is GUI-driven; the script checks prerequisites, builds the demo image
# so it's ready in Podman Desktop's image list, and opens the app. Follow
# README.md for the click-through disk-build + Create VM steps.
#
#   ./run.sh            check, build the demo images (if missing), open Podman Desktop
#   ./run.sh check      check prerequisites only
#   ./run.sh build      build localhost/bootc-demo:v1 + :v1-desktop (arm64) via the CLI
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$ROOT/common/lib.sh"
load_env || true

IMAGE_NAME="${IMAGE_NAME:-bootc-demo}"
BASE_TAG="localhost/${IMAGE_NAME}:v1"
# Overlay adding cloud-init so Podman Desktop's "Create VM" (macadam) can inject
# the login user + SSH key at first boot — the base image ships no cloud-init.
DESKTOP_TAG="localhost/${IMAGE_NAME}:v1-desktop"

cmd_build() {
  require_cmd podman
  if podman image exists "$BASE_TAG"; then
    ok "$BASE_TAG already present"
  else
    log "Building $BASE_TAG (native arch) so it shows up in Podman Desktop"
    podman build --build-arg VERSION=v1 \
      -f "$ROOT/common/Containerfile.base" -t "$BASE_TAG" "$ROOT/common"
    ok "built $BASE_TAG"
  fi
  if podman image exists "$DESKTOP_TAG"; then
    ok "$DESKTOP_TAG already present"
  else
    log "Building $DESKTOP_TAG (adds cloud-init for macadam 'Create VM')"
    podman build --build-arg "FROM_IMAGE=$BASE_TAG" \
      -f "$HERE/Containerfile" -t "$DESKTOP_TAG" "$HERE"
    ok "built $DESKTOP_TAG — use THIS image for the disk build"
  fi
}

cmd_check() {
  local ok=1
  if [ "$(uname -s)" != "Darwin" ]; then
    warn "This demo targets macOS + Podman Desktop. On Linux use demo 03 (bcvk)."
  fi
  if [ -d "/Applications/Podman Desktop.app" ]; then
    ok "Podman Desktop is installed"
  else
    warn "Podman Desktop not found — install from https://podman-desktop.io/downloads"
    ok=0
  fi
  if command -v podman >/dev/null 2>&1 && podman machine list >/dev/null 2>&1; then
    ok "podman machine present:"; podman machine list || true
  else
    warn "no running podman machine — start one in Podman Desktop first"
  fi
  # macadam (the VM launcher behind "Create VM") only supports ed25519 SSH keys.
  if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    ok "ed25519 SSH key present (required by 'Create VM')"
  else
    warn "no ~/.ssh/id_ed25519 — 'Create VM' needs an ed25519 key. Generate one:"
    warn "  ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519"
  fi
  echo
  log "In Podman Desktop, install the 'Bootc' extension (Extensions > Catalog)."
  log "Build the disk from '$DESKTOP_TAG' (has cloud-init) — NOT the plain :v1."
  [ "$ok" -eq 1 ] || warn "resolve the warnings above, then re-run"
}

case "${1:-open}" in
  check) cmd_check ;;
  build) cmd_build ;;
  open)
    cmd_check
    cmd_build
    if [ -d "/Applications/Podman Desktop.app" ]; then
      log "Opening Podman Desktop — follow README.md from here"
      open -a "Podman Desktop"
    fi
    ;;
  *) die "usage: $0 [check|build|open]" ;;
esac
