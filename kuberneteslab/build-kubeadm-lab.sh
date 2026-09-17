#!/bin/bash

set -e

CONTROL_IP="192.168.178.51"

echo "Kubernetes Lab Builder"
echo
echo "1) Build"
echo "2) Reset"
read -p "Choice: " CHOICE

if [[ "$CHOICE" == "2" ]]; then

    sudo kubeadm reset -f

    sudo rm -rf \
      /etc/cni/net.d \
      /var/lib/cni \
      /etc/kubernetes \
      ~/.kube

    echo "Cluster reset."
    exit 0
fi

cat > config.yaml <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "${CONTROL_IP}:6443"

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
EOF

sudo kubeadm init --config config.yaml

mkdir -p $HOME/.kube

sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $USER:$USER $HOME/.kube/config

read -p "Install Calico? (y/n): " CALICO

if [[ "$CALICO" == "y" ]]; then

kubectl apply -f \
https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/calico.yaml

fi

read -p "Install Local Path StorageClass? (y/n): " STORAGE

if [[ "$STORAGE" == "y" ]]; then

kubectl apply -f \
https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

fi

read -p "Install Helm? (y/n): " HELM

if [[ "$HELM" == "y" ]]; then

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

helm repo add stable https://charts.helm.sh/stable

helm repo update

fi

echo
echo "Join command:"
sudo kubeadm token create --print-join-command
