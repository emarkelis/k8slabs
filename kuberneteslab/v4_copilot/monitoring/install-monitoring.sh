#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Monitoring Stack"

if ! command -v helm >/dev/null 2>&1
then
    echo "Helm is required."
    exit 1
fi

helm repo add prometheus-community \
https://prometheus-community.github.io/helm-charts

helm repo update

kubectl create namespace monitoring \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

helm upgrade \
  --install monitoring \
  prometheus-community/kube-prometheus-stack \
  -f "${SCRIPT_DIR}/values/kube-prometheus-stack.yaml" \
  -n monitoring

echo
echo "Monitoring installation completed."
