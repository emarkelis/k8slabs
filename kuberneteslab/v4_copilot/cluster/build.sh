#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${ROOT_DIR}/config/cluster.conf"
source "${ROOT_DIR}/config/addons.conf"

KUBEADM_CONFIG="/tmp/kubeadm-config.yaml"

echo
echo "======================================="
echo " Kubernetes Lab v4 Build"
echo "======================================="

echo
echo "Generating kubeadm configuration..."

export CONTROL_HOST
export CONTROL_IP
export POD_CIDR

envsubst < "${SCRIPT_DIR}/kubeadm-config.template" \
  > "${KUBEADM_CONFIG}"

echo
cat "${KUBEADM_CONFIG}"

echo
echo "Initializing control plane..."

sudo kubeadm init \
  --config "${KUBEADM_CONFIG}"

echo
echo "Configuring kubectl..."

mkdir -p "${HOME}/.kube"

sudo cp \
  /etc/kubernetes/admin.conf \
  "${HOME}/.kube/config"

sudo chown \
  "$(id -u):$(id -g)" \
  "${HOME}/.kube/config"

echo
echo "Installing configured addons..."

if [[ "${ENABLE_CALICO}" == "true" ]]
then
    "${ROOT_DIR}/addons/calico.sh" install
fi

if [[ "${ENABLE_HELM}" == "true" ]]
then
    "${ROOT_DIR}/addons/helm.sh" install
fi

if [[ "${ENABLE_STORAGE}" == "true" ]]
then
    "${ROOT_DIR}/addons/storage.sh" install
fi

echo
echo "Cluster build complete."

echo
echo "Next Step:"
echo
echo "cluster/join-workers.sh"
