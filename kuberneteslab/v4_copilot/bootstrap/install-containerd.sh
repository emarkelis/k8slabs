#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../config/versions.conf"

echo "========================================="
echo "Installing Container Runtime"
echo "========================================="

sudo apt update

sudo apt install -y \
  ca-certificates \
  curl \
  wget \
  jq \
  gnupg \
  apt-transport-https \
  software-properties-common

#
# Required kernel modules
#

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

#
# Required sysctl settings
#

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

#
# Containerd
#

echo "Installing containerd..."

sudo apt install -y containerd

sudo mkdir -p /etc/containerd

containerd config default \
 | sudo tee /etc/containerd/config.toml >/dev/null

sudo sed -i \
  's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml

sudo systemctl daemon-reload

sudo systemctl enable containerd

sudo systemctl restart containerd

sleep 3

echo
echo "Containerd Status:"
systemctl is-active containerd

echo
containerd --version

echo
echo "Containerd installation complete."
