#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

log "Generating join command"
JOIN_CMD=$(run_remote "${CONTROL_IP}" "sudo kubeadm token create --print-join-command")

for i in "${!WORKER_IPS[@]}"; do
  ip="${WORKER_IPS[$i]}"
  name="${WORKER_NAMES[$i]}"
  log "Joining ${name} (${ip})"
  run_remote "${ip}" "sudo ${JOIN_CMD} --node-name=${name}"
  ok "${name} joined"
done
