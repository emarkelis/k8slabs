#!/usr/bin/env bash
# Initializes the single control plane.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

validate_config
require_command ssh
require_command scp

log "Initialising control plane ${CONTROL_NAME} (${CONTROL_IP})."

KUBEADM_VERSION="$(run_remote "${CONTROL_IP}" 'sudo kubeadm version -o short')"
[[ "${KUBEADM_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
    die "Unexpected kubeadm version returned: ${KUBEADM_VERSION}"

cat > "${ROOT_DIR}/.kubeadm-v7.yaml" <<EOF_KUBEADM
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${CONTROL_IP}
  bindPort: 6443
nodeRegistration:
  name: ${CONTROL_NAME}
  criSocket: unix:///run/containerd/containerd.sock
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: ${KUBEADM_VERSION}
controlPlaneEndpoint: "${CONTROL_IP}:6443"
networking:
  podSubnet: "${POD_CIDR}"
  serviceSubnet: "${SERVICE_CIDR}"
  dnsDomain: "${CLUSTER_DNS_DOMAIN}"
apiServer:
  certSANs:
    - "${CONTROL_NAME}"
    - "${CONTROL_IP}"
EOF_KUBEADM

trap 'rm -f "${ROOT_DIR}/.kubeadm-v7.yaml"' EXIT

scp_to "${CONTROL_IP}" \
    "${ROOT_DIR}/.kubeadm-v7.yaml" \
    "${REMOTE_WORKDIR}/kubeadm-config.yaml"

run_remote "${CONTROL_IP}" \
    "sudo kubeadm init --config '${REMOTE_WORKDIR}/kubeadm-config.yaml'"

run_remote "${CONTROL_IP}" \
    'mkdir -p "$HOME/.kube" && sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config" && sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config" && chmod 600 "$HOME/.kube/config"'

run_remote "${CONTROL_IP}" 'kubectl get nodes -o wide'
ok "Control plane initialized."
