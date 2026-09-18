#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

helm repo add open-telemetry \
https://open-telemetry.github.io/opentelemetry-helm-charts

helm repo update

kubectl create namespace monitoring \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

helm upgrade \
  --install otel \
  open-telemetry/opentelemetry-collector \
  -f "${SCRIPT_DIR}/values/otel-collector.yaml" \
  -n monitoring
`
