#!/usr/bin/env bash

set -euo pipefail

helm uninstall monitoring -n monitoring || true

kubectl delete namespace monitoring \
  --ignore-not-found=true

echo "Monitoring removed."
``
