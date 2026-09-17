#!/bin/bash

set -e

echo "Stopping Minikube..."
minikube stop || true

echo "Deleting Minikube cluster..."
minikube delete --all --purge || true

echo "Removing kubeconfig..."
rm -rf ~/.kube

echo "Removing Minikube files..."
rm -rf ~/.minikube

echo "Removing cached Kubernetes manifests..."
rm -rf ~/.kube/cache

echo "Removing local kubectl cache..."
rm -rf ~/.kube/http-cache

echo "Removing CNI leftovers..."
sudo rm -rf /etc/cni/net.d

echo "Removing kubelet leftovers..."
sudo rm -rf /var/lib/kubelet

echo "Cleanup completed."
