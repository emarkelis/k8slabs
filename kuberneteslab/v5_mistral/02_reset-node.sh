#!/bin/bash
# v4_mistral - Reset a Kubernetes node: Wipe all Kubernetes state
# This script is copied to and run ON each node (control and workers)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lab.conf"

print_header "Resetting Kubernetes Node"

NODE_NAME="$1"
if [[ -z "$NODE_NAME" ]]; then
    log_error "Usage: $0 <NODE_NAME>"
    exit 1
fi

log_info "Resetting node: ${NODE_NAME}"

# --- Reset kubeadm ---
log_info "Running kubeadm reset..."
sudo kubeadm reset -f || true

# --- Remove Kubernetes directories ---
log_info "Removing Kubernetes directories..."
sudo rm -rf /etc/kubernetes/*
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /var/lib/etcd/*

# --- Remove CNI configuration ---
log_info "Removing CNI configuration..."
sudo rm -rf /etc/cni/net.d/*

# --- Remove CNI network interfaces ---
log_info "Removing CNI network interfaces..."
# List of common CNI interfaces
CNI_INTERFACES=("cni0" "flannel.1" "vxlan.calico" "tunl0" "kube-ipvs0")
for iface in "${CNI_INTERFACES[@]}"; do
    if ip link show "$iface" &>/dev/null; then
        sudo ip link delete "$iface" || true
    fi
done

# --- Flush iptables rules ---
log_info "Flushing iptables rules..."
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F
sudo iptables -X

# --- Flush ipvs rules (for kube-proxy) ---
log_info "Flushing ipvs rules..."
sudo ipvsadm --clear || true

# --- Remove old containerd data ---
log_info "Cleaning up containerd..."
sudo rm -rf /var/lib/containerd/*

# --- Restart containerd and kubelet ---
log_info "Restarting containerd and kubelet..."
sudo systemctl restart containerd || true
sudo systemctl restart kubelet || true

# --- Remove old kubeconfig ---
log_info "Removing old kubeconfig..."
rm -f "$HOME/.kube/config"

log_success "Node ${NODE_NAME} has been reset and is ready for redeployment."
