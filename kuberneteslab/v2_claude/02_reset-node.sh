#!/bin/bash
# 02_reset-node.sh
# Wipes a node's Kubernetes state completely (kubeadm, CNI, iptables,
# kubelet) while leaving the installed packages alone. Runs LOCALLY on
# the node it's copied to. Safe to run repeatedly, including on a node
# that was never initialized — every step tolerates "nothing to clean up".
#
# This is what makes redeploys reliable: without clearing CNI interfaces
# and iptables rules, a fresh kubeadm init/join can silently inherit
# stale networking state from the previous cluster.

set -e

echo "=== [$(hostname)] Resetting Kubernetes state ==="

sudo systemctl stop kubelet 2>/dev/null || true
sudo kubeadm reset -f 2>/dev/null || true

sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet/*
sudo rm -rf /etc/cni/net.d /var/lib/cni

echo "-> removing leftover CNI interfaces"
for IFACE in cni0 flannel.1 vxlan.calico vxlan-v6.calico tunl0 wireguard.cali; do
  if ip link show "$IFACE" &>/dev/null; then
    sudo ip link delete "$IFACE" || true
  fi
done

if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
  echo "-> ufw is active, skipping raw iptables flush (would risk locking out SSH)"
else
  echo "-> flushing iptables rules left by kube-proxy/CNI"
  sudo iptables -F 2>/dev/null || true
  sudo iptables -t nat -F 2>/dev/null || true
  sudo iptables -t mangle -F 2>/dev/null || true
  sudo iptables -X 2>/dev/null || true
fi

if command -v ipvsadm &>/dev/null; then
  sudo ipvsadm -C || true
fi

sudo systemctl restart containerd
rm -rf "$HOME/.kube"
sudo systemctl daemon-reload

echo "=== [$(hostname)] Reset complete ==="
