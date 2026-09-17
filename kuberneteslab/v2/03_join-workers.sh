#!/bin/bash
# 03_join-workers.sh
# Run on the control node (after 02_init-control.sh). Resets each worker
# to a clean state over SSH, then joins it to the cluster.

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lab.conf"
source "$DIR/lib/common.sh"

JOIN_CMD=$(sudo kubeadm token create --print-join-command)

for HOST in "${WORKER_HOSTS[@]}"; do
  log "Resetting ${HOST}..."
  scp_to "$DIR/01_reset-node.sh" "$HOST" /tmp/01_reset-node.sh
  ssh_run "$HOST" "chmod +x /tmp/01_reset-node.sh && /tmp/01_reset-node.sh"

  log "Joining ${HOST} to the cluster..."
  ssh_run "$HOST" "sudo ${JOIN_CMD}"
done

log "All workers joined. Verify with: kubectl get nodes"
