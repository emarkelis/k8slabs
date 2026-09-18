#!/bin/bash
# 03_init-control.sh
# Orchestration script — run on YOUR machine, not on a VM.
# Initializes the kubeadm control plane on ${CONTROL_NAME} over SSH.
# Assumes 01_bootstrap-node.sh and 02_reset-node.sh already ran there.

set -e
DIR="$(cd "$(dirname -- "$0")" && pwd)"
source "$DIR/lab.conf"
source "$DIR/lib/common.sh"

log "Checking installed Kubernetes version on ${CONTROL_NAME}..."
K8S_INSTALLED="$(ssh_run "$CONTROL_IP" "kubeadm version -o short")"

log "Generating kubeadm config (kubernetesVersion=${K8S_INSTALLED})..."
CONFIG_FILE="$(mktemp)"
cat > "$CONFIG_FILE" <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: ${K8S_INSTALLED}
controlPlaneEndpoint: "${CONTROL_NAME}:6443"
networking:
  podSubnet: ${POD_CIDR}
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${CONTROL_IP}
  bindPort: 6443
nodeRegistration:
  name: ${CONTROL_NAME}
  criSocket: unix:///run/containerd/containerd.sock
EOF

scp_to "$CONFIG_FILE" "$CONTROL_IP" "/tmp/kubeadm-config.yaml"
rm -f "$CONFIG_FILE"

log "Running kubeadm init on ${CONTROL_NAME}..."
ssh_run "$CONTROL_IP" "sudo kubeadm init --config /tmp/kubeadm-config.yaml"

log "Configuring kubectl for ${SSH_USER} on ${CONTROL_NAME}..."
ssh_run "$CONTROL_IP" "
  mkdir -p \$HOME/.kube
  sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config
  sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config
"

log "Control plane ready."
