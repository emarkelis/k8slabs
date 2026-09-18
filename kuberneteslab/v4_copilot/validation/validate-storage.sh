#!/usr/bin/env bash

set -euo pipefail

kubectl get storageclass

kubectl get pvc -A
