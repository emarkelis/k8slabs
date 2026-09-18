#!/bin/bash
# 01_bootstrap-node.sh
# Installs containerd + kubeadm/kubelet/kubectl and the required kernel/
# sysctl settings. Runs LOCALLY on the node it's copied to. Every step
# here is idempotent — safe to run again on a node that's already set up.

set -e
DIR="$(cd "$(dirname -- "$0")" && pwd)"
source "$DIR/lab.conf"

echo "=== [$(hostname)] Bootstrapping Kubernetes node ==="

sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg software-properties-common

echo "-> disabling swap"
sudo swapoff -a
sudo sed -i.bak '/ swap / s/^/#/' /etc/fstab

echo "-> kernel modules"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

echo "-> sysctl"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system >/dev/null

echo "-> containerd"
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd >/dev/null

echo "-> kubeadm / kubelet / kubectl (${K8S_VERSION})"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
  | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
sudo apt update
sudo apt-mark unhold kubelet kubeadm kubectl >/dev/null 2>&1 || true
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl >/dev/null

echo "=== [$(hostname)] Bootstrap complete: $(kubeadm version -o short) ==="
