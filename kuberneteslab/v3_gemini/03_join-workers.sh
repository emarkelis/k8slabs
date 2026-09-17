#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cluster.env"

run_ssh() {
  local target_ip="$1"
  local cmd="$2"
  if [ -n "${SSH_PASS}" ]; then
    sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no "${SSH_USER}@${target_ip}" "${cmd}"
  else
    ssh -o StrictHostKeyChecking=no "${SSH_USER}@${target_ip}" "${cmd}"
  fi
}

echo "==> [JOIN] Generating dynamic join token..."
JOIN_CMD=$(sudo kubeadm token create --print-join-command)

for i in "${!WORKER_IPS[@]}"; do
  w_name="${WORKER_NAMES[$i]}"
  w_ip="${WORKER_IPS[$i]}"
  echo "==> [JOIN] Joining node ${w_name} (${w_ip}) to cluster..."
  run_ssh "${w_ip}" "sudo ${JOIN_CMD} --node-name ${w_name}"
done

echo "==> [JOIN] All worker nodes joined successfully!"
