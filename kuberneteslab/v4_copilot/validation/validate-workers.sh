#!/usr/bin/env bash

set -euo pipefail

kubectl get nodes

echo
echo "Worker Status"

kubectl get nodes \
-o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type
