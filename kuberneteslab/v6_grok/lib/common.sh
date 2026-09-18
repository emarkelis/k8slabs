#!/usr/bin/env bash
# Shared helpers for v6_grok

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lab.conf"

# All nodes in order: control first, then workers
ALL_NAMES=("${CONTROL_NAME}" "${WORKER_NAMES[@]}")
ALL_IPS=("${CONTROL_IP}" "${WORKER_IPS[@]}")

ssh_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i "${SSH_KEY}")

run_remote() {
  local ip="$1"
  shift
  ssh "${ssh_opts[@]}" "${SSH_USER}@${ip}" "$@"
}

scp_to() {
  local ip="$1"
  local src="$2"
  local dst="$3"
  scp "${ssh_opts[@]}" -r "${src}" "${SSH_USER}@${ip}:${dst}"
}

log()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m    $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
die()  { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

check_ssh() {
  local ip="$1"
  if ! run_remote "${ip}" "true" &>/dev/null; then
    die "Cannot SSH to ${ip}. Run ./00_prepare-nodes.sh first or check connectivity."
  fi
}
