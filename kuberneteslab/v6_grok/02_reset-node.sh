#!/usr/bin/env bash
# Thorough, idempotent wipe of Kubernetes state
set -euo pipefail

log() { echo -e "\033[1;33m[RESET]\033[0m $*"; }

log "Running kubeadm reset"
sudo kubeadm reset -f || true

log "Removing leftover directories"
sudo rm -rf \
  /etc/cni/net.d \
  /var/lib/cni \
  /var/lib/kubelet/* \
  /var/lib/etcd \
  /etc/kubernetes \
  ~/.kube \
  /var/lib/calico \
  /var/lib/kube-proxy || true

log "Cleaning CNI interfaces"
for iface in cni0 flannel.1 vxlan.calico cali* tunl0; do
  sudo ip link delete "${iface}" 2>/dev/null || true
done

log "Flushing iptables (kube-proxy / CNI leftovers)"
sudo iptables -F || true
sudo iptables -t nat -F || true
sudo iptables -t mangle -F || true
sudo iptables -X || true

log "Reset complete on $(hostname)"
