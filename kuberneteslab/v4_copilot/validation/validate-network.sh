#!/usr/bin/env bash

set -euo pipefail

echo "Calico"

kubectl get pods -n calico-system

echo
echo "DNS"

kubectl get pods -n kube-system | grep coredns
