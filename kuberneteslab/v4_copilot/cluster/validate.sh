#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo
echo "======================================="
echo " Cluster Validation"
echo "======================================="

echo
echo "Nodes"
kubectl get nodes -o wide

echo
echo "System Pods"
kubectl get pods -A

echo
echo "Storage"
"${ROOT_DIR}/validation/validate-storage.sh"

echo
echo "Networking"
"${ROOT_DIR}/validation/validate-network.sh"

echo
echo "Monitoring"
"${ROOT_DIR}/validation/validate-monitoring.sh"

echo
echo "Workers"
"${ROOT_DIR}/validation/validate-workers.sh"

echo
echo "Validation complete."
