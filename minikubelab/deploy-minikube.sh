#!/bin/bash

set -e

echo "=== Minikube Lab Setup ==="

#
# Install prerequisites
#

sudo apt update

sudo apt install -y \
    curl \
    wget \
    jq \
    apt-transport-https \
    ca-certificates \
    docker.io

sudo systemctl enable docker
sudo systemctl start docker

#
# Install kubectl if missing
#

if ! command -v kubectl >/dev/null 2>&1
then

    VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)

    curl -LO "https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubectl"

    chmod +x kubectl

    sudo mv kubectl /usr/local/bin/
fi

#
# Install Minikube if missing
#

if ! command -v minikube >/dev/null 2>&1
then

    curl -LO \
    https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

    sudo install \
         minikube-linux-amd64 \
         /usr/local/bin/minikube
fi

echo
echo "Installed versions"
echo

kubectl version --client

minikube version

docker --version

echo
echo "Deleting old cluster (if any)"
echo

minikube delete || true

echo
echo "Creating fresh cluster"
echo

minikube start \
    --driver=docker \
    --cpus=4 \
    --memory=8192 \
    --disk-size=25g

#
# Calico
#

read -p "Install Calico networking? (y/n): " CALICO

if [[ "$CALICO" == "y" ]]
then

kubectl apply -f \
https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/calico.yaml

fi

#
# Storage Class
#

read -p "Enable default Minikube StorageClass? (y/n): " STORAGE

if [[ "$STORAGE" == "y" ]]
then

minikube addons enable storage-provisioner

minikube addons enable default-storageclass

fi

#
# Helm
#

read -p "Install Helm? (y/n): " HELM

if [[ "$HELM" == "y" ]]
then

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
| bash

fi

echo
echo "================================"
echo "Cluster Status"
echo "================================"

kubectl get nodes

kubectl get pods -A

kubectl get sc || true

helm version 2>/dev/null || true

echo
echo "Minikube lab environment ready"
