#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../config/versions.conf"

CALICO_URL="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

ACTION="${1:-install}"

case "${ACTION}" in

install)

    kubectl apply -f "${CALICO_URL}"

    ;;

remove)

    kubectl delete -f "${CALICO_URL}" \
      --ignore-not-found=true

    ;;

upgrade)

    kubectl apply -f "${CALICO_URL}"

    ;;

validate)

    kubectl get pods -n calico-system

    ;;

*)

    echo "Unsupported action"

    exit 1

esac
