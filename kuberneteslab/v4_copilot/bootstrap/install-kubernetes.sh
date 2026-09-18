#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../config/versions.conf"

echo "========================================="
echo "Installing Kubernetes Tools"
echo "========================================="

#
# Disable swap
#

sudo swapoff -a

sudo sed -i.bak '/ swap / s/^/#/' /etc/fstab

#
# Determine Kubernetes version
#

if [[ "${VERSION_MODE}" == "latest" ]]
then

    K8S_RELEASE=$(curl -fsSL \
        https://dl.k8s.io/release/stable.txt)

    K8S_MINOR=$(echo "${K8S_RELEASE}" \
      | grep -oE 'v[0-9]+\.[0-9]+')

else

    K8S_MINOR="${K8S_VERSION}"

fi

echo
echo "Using Kubernetes repository: ${K8S_MINOR}"
echo

sudo mkdir -p /etc/apt/keyrings

curl -fsSL \
"https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
| sudo gpg --dearmor \
-o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo \
"deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" \
| sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

sudo apt update

sudo apt install -y \
    kubelet \
    kubeadm \
    kubectl

sudo apt-mark hold \
    kubelet \
    kubeadm \
    kubectl

sudo systemctl enable kubelet

echo
echo "Installed versions"
echo

kubeadm version

echo
kubectl version --client

echo
echo "Kubernetes package installation complete."
