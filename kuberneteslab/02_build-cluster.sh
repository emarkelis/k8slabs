#!/bin/bash

set -e

CONTROL_IP=192.168.178.51

echo
echo "=== Kubeadm Cluster Setup ==="
echo

read -p "Reset existing cluster? (y/n) : " RESET

if [[ "$RESET" == "y" ]]
then

sudo kubeadm reset -f

sudo rm -rf \
 /etc/cni/net.d \
 /var/lib/cni \
 /var/lib/kubelet/* \
 /etc/kubernetes \
 ~/.kube

fi

cat > kubeadm-config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration

controlPlaneEndpoint: "control:6443"

networking:
  podSubnet: 10.244.0.0/16

---
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration

localAPIEndpoint:
  advertiseAddress: ${CONTROL_IP}
  bindPort: 6443

nodeRegistration:
  name: control
  criSocket: unix:///run/containerd/containerd.sock

EOF

sudo kubeadm init \
 --config kubeadm-config.yaml

mkdir -p $HOME/.kube

sudo cp \
 /etc/kubernetes/admin.conf \
 $HOME/.kube/config

sudo chown \
 $USER:$USER \
 $HOME/.kube/config
