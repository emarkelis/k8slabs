#!/bin/bash
# 04_join-workers.sh
# Orchestration script — run on YOUR machine, not on a VM.
# Fetches a fresh join command from the control node and runs it on
# each worker over SSH. Assumes the workers have already been
# bootstrapped (01) and reset (02).

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lab.conf"
source "$DIR/lib/common.sh"

log "Requesting a join command from ${CONTROL_NAME}..."
JOIN_CMD="$(ssh_run "$CONTROL_IP" "sudo kubeadm token create --print-join-command")"

for i in "${!WORKER_NAMES[@]}"; do
  NAME="${WORKER_NAMES[$i]}"
  IP="${WORKER_IPS[$i]}"
  log "Joining ${NAME} (${IP})..."
  ssh_run "$IP" "sudo ${JOIN_CMD}"
done

log "All workers joined."
