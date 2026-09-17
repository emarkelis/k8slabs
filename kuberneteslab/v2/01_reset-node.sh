#!/bin/bash
# 01_reset-node.sh
# Fully wipes a node's Kubernetes state — kubeadm, CNI, iptables, kubelet —
# while leaving the OS/kubeadm packages installed. Run locally on whichever
# node is being reset (works the same for control or worker).
#
# This is what makes destroy/redeploy repeatable: without clearing the CNI
# interfaces and iptables rules, a fresh `kubeadm init`/`join` can silently
# inherit stale networking state from the previous cluster.

set -e

echo "=== Resetting Kubernetes node ==="

echo "Stopping kubelet..."
sudo systemctl stop kubelet || true

echo "Running kubeadm reset..."
sudo kubeadm reset -f || true

echo "Removing Kubernetes config, etcd, kubelet state..."
sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet/*

echo "Removing CNI config and state..."
sudo rm -rf /etc/cni/net.d /var/lib/cni

echo "Removing leftover CNI network interfaces..."
for IFACE in cni0 flannel.1 vxlan.calico vxlan-v6.calico tunl0 wireguard.cali; do
  if ip link show "$IFACE" &>/dev/null; then
    sudo ip link delete "$IFACE" || true
  fi
done

if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
  echo "ufw is active — skipping raw iptables flush to avoid locking out SSH."
else
  echo "Flushing iptables rules left by kube-proxy/CNI..."
  sudo iptables -F || true
  sudo iptables -t nat -F || true
  sudo iptables -t mangle -F || true
  sudo iptables -X || true
fi

if command -v ipvsadm &>/dev/null; then
  echo "Clearing IPVS tables..."
  sudo ipvsadm -C || true
fi

echo "Restarting containerd..."
sudo systemctl restart containerd

echo "Removing local kubeconfig..."
rm -rf "$HOME/.kube"

echo "Reloading systemd..."
sudo systemctl daemon-reload

echo "Node reset complete."
