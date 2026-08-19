#!/usr/bin/env bash
# Demo 01 — Create a bootc container.
# Builds the shared demo OS image from common/Containerfile.base and runs the
# bootc linter. This image is the artifact every other demo consumes.
#
#   ./run.sh            build the image (VERSION=v1) and show the lint result
#   ./run.sh cleanup    remove the built image
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/common/lib.sh"
load_env || true

BASE_IMAGE="${BASE_IMAGE:-quay.io/centos-bootc/centos-bootc:stream10}"
IMAGE_NAME="${IMAGE_NAME:-bootc-demo}"
LOCAL_TAG="localhost/${IMAGE_NAME}:v1"
CONTAINERFILE="$ROOT/common/Containerfile.base"

cmd_build() {
  require_cmd podman
  log "Building $LOCAL_TAG"
  log "  base:  $BASE_IMAGE"
  log "  arch:  $(oci_arch)"
  podman build \
    --build-arg "BASE=$BASE_IMAGE" \
    --build-arg "VERSION=v1" \
    -f "$CONTAINERFILE" \
    -t "$LOCAL_TAG" \
    "$ROOT/common"
  ok "built $LOCAL_TAG"

  echo
  log "Image bootc metadata (label containers.bootc=1 marks it bootable):"
  podman image inspect "$LOCAL_TAG" \
    --format '  {{.Id}}
  size: {{.Size}}
  labels: {{range $k,$v := .Labels}}{{$k}}={{$v}} {{end}}' || true

  echo
  log "Re-running 'bootc container lint' for visibility (it also ran during build):"
  # Runs the linter that is baked as the final build step, so you can see output.
  if podman run --rm "$LOCAL_TAG" bootc container lint; then
    ok "lint passed"
  else
    warn "lint reported issues (see above)"
  fi

  echo
  ok "Done. Next: demos/02-run-as-plain-container to run this image as a container."
}

cmd_cleanup() {
  log "Removing $LOCAL_TAG"
  podman rmi -f "$LOCAL_TAG" 2>/dev/null || true
  ok "cleaned up"
}

case "${1:-build}" in
  build)   cmd_build ;;
  cleanup) cmd_cleanup ;;
  *) die "usage: $0 [build|cleanup]" ;;
esac
