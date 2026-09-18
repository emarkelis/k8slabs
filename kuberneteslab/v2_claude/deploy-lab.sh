#!/bin/bash
# deploy-lab.sh
# THE command you run to build the lab — and the same command you run
# to rebuild it. It always resets every node to a clean state before
# rebuilding, so "redeploy" simply means: run this again.
#
# Run this from your own machine (not from inside any VM) — it only
# needs SSH access to control/worker01/worker03.

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lab.conf"
source "$DIR/lib/common.sh"

ALL_NAMES=("$CONTROL_NAME" "${WORKER_NAMES[@]}")
ALL_IPS=("$CONTROL_IP" "${WORKER_IPS[@]}")

log "=== Deploying lab: ${ALL_NAMES[*]} ==="

log "Step 1/6 — checking SSH to every node"
for ip in "${ALL_IPS[@]}"; do
  wait_for_ssh "$ip"
done

log "Step 2/6 — configuring /etc/hosts on every node"
for ip in "${ALL_IPS[@]}"; do
  setup_hosts_remote "$ip"
done

log "Step 3/6 — syncing scripts and bootstrapping packages on every node"
for i in "${!ALL_IPS[@]}"; do
  sync_node "${ALL_IPS[$i]}"
  log "  bootstrapping ${ALL_NAMES[$i]}..."
  ssh_run "${ALL_IPS[$i]}" "${REMOTE_WORKDIR}/01_bootstrap-node.sh"
done

log "Step 4/6 — resetting every node to a clean Kubernetes state"
for i in "${!ALL_IPS[@]}"; do
  log "  resetting ${ALL_NAMES[$i]}..."
  ssh_run "${ALL_IPS[$i]}" "${REMOTE_WORKDIR}/02_reset-node.sh"
done

log "Step 5/6 — initializing control plane and joining workers"
"$DIR/03_init-control.sh"
"$DIR/04_join-workers.sh"

log "Step 6/6 — installing Calico networking and local-path storage"
"$DIR/05_cluster-components.sh" install calico
"$DIR/05_cluster-components.sh" install storage

log "Waiting for all nodes to report Ready (up to 3 minutes)..."
READY=0
for _ in $(seq 1 18); do
  READY="$(ssh_run "$CONTROL_IP" "kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready '" || echo 0)"
  if [[ "$READY" -ge "${#ALL_NAMES[@]}" ]]; then
    break
  fi
  sleep 10
done

echo
ssh_run "$CONTROL_IP" "kubectl get nodes -o wide"
echo
log "=== Deployment complete ==="
echo "Run kubectl from the control node:  ssh -i ${SSH_KEY} ${SSH_USER}@${CONTROL_IP}"
echo "...or fetch a local kubeconfig:      ./fetch-kubeconfig.sh"
