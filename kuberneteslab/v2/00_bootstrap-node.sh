#!/bin/bash
# 00_bootstrap-node.sh
# Installs containerd + kubeadm/kubelet/kubectl and applies the kernel/sysctl
# prerequisites. Safe to re-run — every step here is idempotent.
# Run on EVERY node (control + both workers).

set -e

echo "=== Kubernetes Node Bootstrap ==="

sudo apt update

sudo apt install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  jq \
  wget \
  gnupg \
  software-properties-common

#
# disable swap
#

sudo swapoff -a
sudo sed -i.bak '/ swap / s/^/#/' /etc/fstab

#
# kernel modules
#

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

#
# sysctl
#

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

#
# containerd
#

sudo apt install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

#
# kubernetes
#

K8S_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
VERSION_MINOR=$(echo "$K8S_VERSION" | grep -oE 'v[0-9]+\.[0-9]+')

sudo mkdir -p /etc/apt/keyrings

curl -fsSL \
  "https://pkgs.k8s.io/core:/stable:/${VERSION_MINOR}/deb/Release.key" \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/${VERSION_MINOR}/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update

sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo
echo "Installed:"
kubeadm version
kubectl version --client
