#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cluster.env"

echo "==> [CONTROL] Initializing Kubernetes control plane (${CONTROL_NAME} - ${CONTROL_IP})..."
sudo kubeadm init \
  --apiserver-advertise-address="${CONTROL_IP}" \
  --pod-network-cidr="${POD_CIDR}" \
  --node-name "${CONTROL_NAME}"

echo "==> [CONTROL] Configuring local kubectl context..."
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

echo "==> [CONTROL] Deploying Flannel CNI..."
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo "==> [CONTROL] Control plane successfully initialized!"
