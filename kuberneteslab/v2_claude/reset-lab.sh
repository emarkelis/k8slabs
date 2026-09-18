#!/bin/bash
# reset-lab.sh
# Wipes Kubernetes state on all three VMs and stops there — the VMs
# stay running and reachable, only the cluster is torn down. Use this
# when you want a clean slate without immediately rebuilding.
#
# For a full rebuild, you don't need this first — just run
# ./deploy-lab.sh, which resets automatically before it rebuilds.

set -e
DIR="$(cd "$(dirname -- "$0")" && pwd)"
source "$DIR/lab.conf"
source "$DIR/lib/common.sh"

ALL_NAMES=("$CONTROL_NAME" "${WORKER_NAMES[@]}")
ALL_IPS=("$CONTROL_IP" "${WORKER_IPS[@]}")

log "=== Resetting lab (VMs stay running) ==="

for i in "${!ALL_IPS[@]}"; do
  sync_node "${ALL_IPS[$i]}"
  log "Resetting ${ALL_NAMES[$i]}..."
  ssh_run "${ALL_IPS[$i]}" "${REMOTE_WORKDIR}/02_reset-node.sh"
done

log "=== Lab reset. Run ./deploy-lab.sh whenever you want to rebuild it. ==="
