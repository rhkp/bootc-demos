#!/usr/bin/env bash
# Demo 04 — Podman Desktop bootc workflow (macOS, GUI).
# This demo is GUI-driven; the script only checks prerequisites and opens the app.
# Follow README.md for the click-through steps.
#
#   ./run.sh            check prerequisites and open Podman Desktop
#   ./run.sh check      check prerequisites only
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/common/lib.sh"

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
  echo
  log "In Podman Desktop, install the 'Bootc' extension (Extensions > Catalog)."
  [ "$ok" -eq 1 ] || warn "resolve the warnings above, then re-run"
}

case "${1:-open}" in
  check) cmd_check ;;
  open)
    cmd_check
    if [ -d "/Applications/Podman Desktop.app" ]; then
      log "Opening Podman Desktop — follow README.md from here"
      open -a "Podman Desktop"
    fi
    ;;
  *) die "usage: $0 [check|open]" ;;
esac
