#!/bin/bash
# 02_init-control.sh
# Initializes the kubeadm control plane. Run on the control node, after
# 00_bootstrap-node.sh and 01_reset-node.sh have already run there.

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lab.conf"

echo "=== Kubeadm Control Plane Init ==="

cat > /tmp/kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "${CONTROL_HOST}:6443"

networking:
  podSubnet: ${POD_SUBNET}

---
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration

localAPIEndpoint:
  advertiseAddress: ${CONTROL_IP}
  bindPort: 6443

nodeRegistration:
  name: ${CONTROL_HOST}
  criSocket: unix:///run/containerd/containerd.sock
EOF

sudo kubeadm init --config /tmp/kubeadm-config.yaml

mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$USER:$USER" "$HOME/.kube/config"

echo "Control plane ready. kubectl is configured for $USER."
