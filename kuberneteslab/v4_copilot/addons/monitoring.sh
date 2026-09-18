#!/usr/bin/env bash

set -euo pipefail

MONITORING_NS="monitoring"

ACTION="${1:-install}"

install_monitoring() {

    helm repo add prometheus-community \
      https://prometheus-community.github.io/helm-charts

    helm repo update

    kubectl create namespace "${MONITORING_NS}" \
      --dry-run=client \
      -o yaml \
      | kubectl apply -f -

    helm upgrade \
      --install monitoring \
      prometheus-community/kube-prometheus-stack \
      --namespace "${MONITORING_NS}"
}

remove_monitoring() {

    helm uninstall monitoring \
      -n "${MONITORING_NS}" \
      || true
}

validate_monitoring() {

    kubectl get pods \
      -n "${MONITORING_NS}"
}

case "${ACTION}" in

install)

    install_monitoring

    ;;

remove)

    remove_monitoring

    ;;

upgrade)

    install_monitoring

    ;;

validate)

    validate_monitoring

    ;;

*)

    exit 1

esac
