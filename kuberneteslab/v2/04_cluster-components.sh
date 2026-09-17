#!/bin/bash
# 04_cluster-components.sh
# Install/remove cluster add-ons. Run on the control node (kubectl configured).
#
# Usage:
#   ./04_cluster-components.sh install calico
#   ./04_cluster-components.sh remove  storage
#
# Components: calico | helm | storage | monitoring

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lab.conf"

ACTION="$1"
COMPONENT="$2"

if [[ -z "$ACTION" || -z "$COMPONENT" ]]; then
  echo "Usage: $0 <install|remove> <calico|helm|storage|monitoring>"
  exit 1
fi

case "$COMPONENT" in
  calico)
    if [[ "$ACTION" == "install" ]]; then
      kubectl apply -f "${CALICO_URL}"
    else
      kubectl delete -f "${CALICO_URL}" --ignore-not-found
    fi
    ;;

  helm)
    if [[ "$ACTION" == "install" ]]; then
      curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    else
      sudo rm -f /usr/local/bin/helm
    fi
    ;;

  storage)
    if [[ "$ACTION" == "install" ]]; then
      kubectl apply -f "${LOCAL_PATH_URL}"
      kubectl patch storageclass local-path \
        -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
    else
      kubectl delete -f "${LOCAL_PATH_URL}" --ignore-not-found
    fi
    ;;

  monitoring)
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null
    helm repo update >/dev/null

    if [[ "$ACTION" == "install" ]]; then
      kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
      helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring
      helm upgrade --install otel open-telemetry/opentelemetry-collector -n monitoring
    else
      helm uninstall monitoring -n monitoring || true
      helm uninstall otel -n monitoring || true
      kubectl delete ns monitoring --ignore-not-found
    fi
    ;;

  *)
    echo "Unknown component: $COMPONENT"
    exit 1
    ;;
esac

echo "Done: ${ACTION} ${COMPONENT}"
