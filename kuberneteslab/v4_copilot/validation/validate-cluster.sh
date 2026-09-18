#!/usr/bin/env bash

set -euo pipefail

echo "Nodes"

kubectl get nodes -o wide

echo
echo "System Pods"

kubectl get pods -A
