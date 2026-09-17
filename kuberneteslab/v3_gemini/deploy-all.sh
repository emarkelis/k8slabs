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

run_scp() {
  local src="$1"
  local target_ip="$2"
  local dest="$3"
  if [ -n "${SSH_PASS}" ]; then
    sshpass -p "${SSH_PASS}" scp -o StrictHostKeyChecking=no "${src}" "${SSH_USER}@${target_ip}:${dest}"
  else
    scp -o StrictHostKeyChecking=no "${src}" "${SSH_USER}@${target_ip}:${dest}"
  fi
}

echo "=========================================="
echo "    Kubernetes v3 Configurable Deployer"
echo "=========================================="

echo "--> Phase 1: Bootstrapping Control Node (${CONTROL_NAME})..."
"${SCRIPT_DIR}/01_bootstrap-k8s-node.sh"

echo "--> Phase 2: Bootstrapping Worker Nodes over SSH..."
for i in "${!WORKER_IPS[@]}"; do
  w_name="${WORKER_NAMES[$i]}"
  w_ip="${WORKER_IPS[$i]}"
  echo "    Pushing and executing bootstrap on ${w_name} (${w_ip})..."
  run_scp "${SCRIPT_DIR}/cluster.env" "${w_ip}" "/tmp/cluster.env"
  run_scp "${SCRIPT_DIR}/01_bootstrap-k8s-node.sh" "${w_ip}" "/tmp/01_bootstrap-k8s-node.sh"
  run_ssh "${w_ip}" "bash /tmp/01_bootstrap-k8s-node.sh"
done

echo "--> Phase 3: Building Control Plane..."
"${SCRIPT_DIR}/02_build-cluster.sh"

echo "--> Phase 4: Joining Workers..."
"${SCRIPT_DIR}/03_join-workers.sh"

echo "--> Phase 5: Installing Core Cluster Components..."
"${SCRIPT_DIR}/04_cluster_components.sh"

echo "=========================================="
echo "  Deployment Complete! Checking cluster status:"
echo "=========================================="
kubectl get nodes -o wide
