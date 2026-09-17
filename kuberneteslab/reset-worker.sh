#!/bin/bash

set -e

echo "Stopping kubelet..."
sudo systemctl stop kubelet || true

echo "Resetting kubeadm..."
sudo kubeadm reset -f

echo "Removing Kubernetes configuration..."
sudo rm -rf /etc/kubernetes

echo "Removing kubelet state..."
sudo rm -rf /var/lib/kubelet/*

echo "Removing CNI configuration..."
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/cni

echo "Reloading systemd..."
sudo systemctl daemon-reload

echo "Worker reset completed."
