#!/usr/bin/env bash
# Idempotent bootstrap: packages, containerd, kube*, sysctl, hosts
set -euo pipefail

# Expect lab.conf to be present in the same directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lab.conf"

log() { echo -e "\033[1;34m[BOOTSTRAP]\033[0m $*"; }

log "Disabling swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab || true

log "Loading kernel modules"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

log "Sysctl settings"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system >/dev/null

log "Installing containerd"
sudo apt-get update -qq
sudo apt-get install -y -qq containerd apt-transport-https ca-certificates curl gpg

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

log "Kubernetes packages (${K8S_VERSION})"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -qq
sudo apt-get install -y -qq kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

log "Writing /etc/hosts block"
# Remove any previous marked block, then re-add
sudo sed -i '/# BEGIN K8S-LAB/,/# END K8S-LAB/d' /etc/hosts
{
  echo "# BEGIN K8S-LAB"
  echo "${CONTROL_IP} ${CONTROL_NAME}"
  for i in "${!WORKER_NAMES[@]}"; do
    echo "${WORKER_IPS[$i]} ${WORKER_NAMES[$i]}"
  done
  echo "# END K8S-LAB"
} | sudo tee -a /etc/hosts >/dev/null

log "Bootstrap finished on $(hostname)"
