#!/usr/bin/env bash
# common/lib.sh — shared helpers for the bootc demos.
# Source this from a demo's run.sh:  source "$(git rev-parse --show-toplevel)/common/lib.sh"
# All functions are intentionally small and dependency-light.

set -euo pipefail

# ---- pretty logging -------------------------------------------------------
_c_reset=$'\033[0m'; _c_blue=$'\033[34m'; _c_green=$'\033[32m'
_c_yellow=$'\033[33m'; _c_red=$'\033[31m'; _c_bold=$'\033[1m'

log()   { printf '%s==>%s %s\n' "$_c_blue$_c_bold" "$_c_reset" "$*"; }
ok()    { printf '%s ok %s %s\n' "$_c_green$_c_bold" "$_c_reset" "$*"; }
warn()  { printf '%swarn%s %s\n' "$_c_yellow$_c_bold" "$_c_reset" "$*" >&2; }
die()   { printf '%serr %s %s\n' "$_c_red$_c_bold" "$_c_reset" "$*" >&2; exit 1; }

# ---- environment ----------------------------------------------------------

# repo_root: absolute path to the checkout root (works with or without git).
repo_root() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    # fall back to two levels up from a demo dir
    (cd "$(dirname "${BASH_SOURCE[1]:-$0}")/.." && pwd)
  fi
}

# require_cmd CMD [CMD...]: fail early with a friendly message.
require_cmd() {
  local missing=0 c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || { warn "missing required command: $c"; missing=1; }
  done
  [ "$missing" -eq 0 ] || die "install the missing command(s) above and re-run"
}

# load_env: source common/env if present, else fall back to env.example values
# for anything the caller marks required via require_env.
load_env() {
  local root; root="$(repo_root)"
  if [ -f "$root/common/env" ]; then
    # shellcheck disable=SC1091
    set -a; source "$root/common/env"; set +a
    ok "loaded common/env"
  else
    warn "common/env not found — copy common/env.example to common/env and edit it"
  fi
}

# require_env VAR [VAR...]: die if any is empty/unset (used by cloud demos).
require_env() {
  local v missing=0
  for v in "$@"; do
    if [ -z "${!v:-}" ]; then warn "required env var not set: $v"; missing=1; fi
  done
  [ "$missing" -eq 0 ] || die "set the variable(s) above in common/env"
}

# ---- arch -----------------------------------------------------------------
# oci_arch: normalize host arch to OCI/bib naming (amd64 | arm64).
oci_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    *) uname -m ;;
  esac
}

# ---- podman ---------------------------------------------------------------
# ensure_rootful_podman: bib needs the rootful store. On Linux we generally
# run bib with sudo; this just warns if the caller is likely to hit a store
# mismatch.
podman_storage_root() {
  # location bib should bind-mount; rootful default on Linux
  echo /var/lib/containers/storage
}

# ---- ssh helpers ----------------------------------------------------------
# wait_for_ssh HOST [USER] [PORT] [TRIES] [IDENTITY]: poll until sshd answers.
# Pass IDENTITY (a private key path) when logging in with a non-default key —
# otherwise the BatchMode probe can never authenticate and loops until timeout.
wait_for_ssh() {
  local host="$1" user="${2:-root}" port="${3:-22}" tries="${4:-40}" id="${5:-}" i
  local idopt=(); [ -n "$id" ] && idopt=(-o IdentitiesOnly=yes -i "$id")
  log "waiting for ssh at ${user}@${host}:${port} ..."
  for ((i=1; i<=tries; i++)); do
    if ssh -o BatchMode=yes -o StrictHostKeyChecking=no "${idopt[@]}" \
           -o ConnectTimeout=5 -p "$port" "${user}@${host}" true 2>/dev/null; then
      ok "ssh is up"; return 0
    fi
    sleep 5
  done
  die "ssh did not come up after $((tries*5))s"
}

# ---- misc -----------------------------------------------------------------
confirm() { # confirm "message"  -> returns 0 on yes
  local reply; read -r -p "$* [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}
