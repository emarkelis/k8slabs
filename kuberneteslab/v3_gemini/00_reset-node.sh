#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cluster.env"

echo "==> [RESET] Cleaning Kubernetes installation on host: $(hostname)..."

sudo kubeadm reset -f || true
sudo systemctl stop kubelet || true
sudo systemctl stop containerd || true

# Remove network and CNI state
sudo rm -rf /etc/cni/net.d /var/lib/cni/ /var/lib/kubelet/* /var/lib/etcd /etc/kubernetes "$HOME/.kube"

echo "==> [RESET] Removing virtual network interfaces..."
sudo ip link delete cni0 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true

echo "==> [RESET] Flushing iptables..."
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X || true

sudo systemctl start containerd
sudo systemctl start kubelet

echo "==> [RESET] Node clean complete!"
