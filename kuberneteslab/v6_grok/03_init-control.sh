#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

log "Initializing control plane on ${CONTROL_IP}"

run_remote "${CONTROL_IP}" "sudo kubeadm init \
  --apiserver-advertise-address=${CONTROL_IP} \
  --pod-network-cidr=${POD_CIDR} \
  --node-name=${CONTROL_NAME} \
  --control-plane-endpoint=${CONTROL_IP}:6443"

run_remote "${CONTROL_IP}" "
  mkdir -p \$HOME/.kube
  sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config
  sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
"

ok "Control plane initialized"
