#!/usr/bin/env bash
# Demo 02 — Run the bootc image as a plain container.
# Shows the brief's "Standard Container" mode: the SAME image that boots as an
# OS also runs as an ordinary container for dev / CI / inspection — no VM.
#
#   ./run.sh            run the inspection walkthrough
#   ./run.sh web        run httpd via systemd-in-container and curl it
#   ./run.sh cleanup    stop/remove anything this demo started
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/common/lib.sh"
load_env || true

IMAGE_NAME="${IMAGE_NAME:-bootc-demo}"
LOCAL_TAG="localhost/${IMAGE_NAME}:v1"
CNAME="bootc-demo-02-web"

_need_image() {
  podman image exists "$LOCAL_TAG" \
    || die "image $LOCAL_TAG not found — run demos/01-create-bootc-container first"
}

cmd_inspect() {
  require_cmd podman
  _need_image

  log "1) It's a normal OCI image — its bundled kernel is INACTIVE when run as a container:"
  podman run --rm "$LOCAL_TAG" bash -lc \
    'echo "  host kernel (shared): $(uname -r)"; \
     echo "  kernel bundled in image (inert here):"; \
     ls -1 /usr/lib/modules 2>/dev/null | sed "s/^/    /" || echo "    (none)"'

  echo
  log "2) Inspect packages/config without a VM (fast local debugging):"
  podman run --rm "$LOCAL_TAG" bash -lc \
    'rpm -q httpd; echo "  web root ->"; ls -ld /var/www; readlink -f /var/www'

  echo
  log "3) Run the linter as a CI quality gate (this is what you'd do in a pipeline):"
  podman run --rm "$LOCAL_TAG" bootc container lint && ok "lint passed"

  echo
  ok "This same image boots as a full OS in demo 03 — nothing about it changed."
}

cmd_web() {
  require_cmd podman
  _need_image
  cmd_cleanup >/dev/null 2>&1 || true
  log "Starting httpd via systemd INSIDE a container (--systemd=always), port 8080"
  # In this mode systemd is PID 1 inside the container namespace (not the host).
  podman run -d --name "$CNAME" --systemd=always -p 8080:80 "$LOCAL_TAG" /sbin/init >/dev/null
  log "waiting for httpd ..."
  for _ in $(seq 1 20); do
    if curl -fsS http://localhost:8080/ >/dev/null 2>&1; then break; fi; sleep 1
  done
  echo; log "GET http://localhost:8080/ :"
  curl -fsS http://localhost:8080/ || warn "could not reach httpd"
  echo
  ok "Served from the container. Stop it with: ./run.sh cleanup"
}

cmd_cleanup() {
  log "Removing container $CNAME (if any)"
  podman rm -f "$CNAME" 2>/dev/null || true
  ok "cleaned up"
}

case "${1:-inspect}" in
  inspect) cmd_inspect ;;
  web)     cmd_web ;;
  cleanup) cmd_cleanup ;;
  *) die "usage: $0 [inspect|web|cleanup]" ;;
esac
