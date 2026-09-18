#!/bin/bash
# 05_cluster-components.sh
# Orchestration script — run on YOUR machine, not on a VM.
# Installs/removes cluster add-ons by running kubectl/helm on the control
#
# Usage:
#   ./05_cluster-components.sh install calico
#   ./05_cluster-components.sh install helm
#   ./05_cluster-components.sh install monitoring
#   ./05_cluster-components.sh remove  monitoring

set -e
DIR="$(cd "$(dirname -- "$0")" && pwd)"
source "$DIR/lab.conf"
source "$DIR/lib/common.sh"

ACTION="${1:-}"
COMPONENT="${2:-}"

if [[ -z "$ACTION" || -z "$COMPONENT" ]]; then
  echo "Usage: $0 <install|remove> <calico|storage|helm|monitoring>"
  exit 1
fi

case "$COMPONENT" in
  calico)
    if [[ "$ACTION" == "install" ]]; then
      ssh_run "$CONTROL_IP" "kubectl apply -f ${CALICO_URL}"
    else
      ssh_run "$CONTROL_IP" "kubectl delete -f ${CALICO_URL} --ignore-not-found"
    fi
    ;;

  storage)
    if [[ "$ACTION" == "install" ]]; then
      ssh_run "$CONTROL_IP" "kubectl apply -f ${LOCAL_PATH_URL}"
      ssh_run "$CONTROL_IP" "kubectl patch storageclass local-path -p '{\"metadata\":{\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
    else
      ssh_run "$CONTROL_IP" "kubectl delete -f ${LOCAL_PATH_URL} --ignore-not-found"
    fi
    ;;

  helm)
    if [[ "$ACTION" == "install" ]]; then
      log "Installing Helm ${HELM_VERSION} on ${CONTROL_NAME} (skipped if already present)..."
      ssh_run "$CONTROL_IP" "
        if ! command -v helm >/dev/null 2>&1; then
          curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm-3.sh
          chmod +x /tmp/get-helm-3.sh
          DESIRED_VERSION=${HELM_VERSION} /tmp/get-helm-3.sh
        fi
        helm version --short
      "
    else
      ssh_run "$CONTROL_IP" "sudo rm -f /usr/local/bin/helm"
    fi
    ;;

  monitoring)
    if [[ "$ACTION" == "install" ]]; then
      log "Ensuring Helm is installed..."
      bash "$DIR/05_cluster-components.sh" install helm

      log "Adding/updating Helm repos..."
      ssh_run "$CONTROL_IP" "
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
        helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts --force-update
        helm repo update
      "

      log "Creating ${MONITORING_NAMESPACE} namespace..."
      ssh_run "$CONTROL_IP" "kubectl create namespace ${MONITORING_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -"

      log "Installing kube-prometheus-stack (Prometheus + Grafana + Alertmanager)... this can take a few minutes."
      ssh_run "$CONTROL_IP" "helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
        -n ${MONITORING_NAMESPACE} --version ${PROMETHEUS_CHART_VERSION} --wait --timeout 10m"

      log "Installing OpenTelemetry Collector..."
      ssh_run "$CONTROL_IP" "helm upgrade --install otel open-telemetry/opentelemetry-collector \
        -n ${MONITORING_NAMESPACE} --version ${OTEL_CHART_VERSION} --set mode=deployment --wait --timeout 5m"

      echo
      log "Grafana admin password:"
      ssh_run "$CONTROL_IP" "kubectl get secret -n ${MONITORING_NAMESPACE} monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d && echo"
      echo
      echo "View Grafana with:"
      echo "  ssh -L 3000:localhost:3000 -i ${SSH_KEY} ${SSH_USER}@${CONTROL_IP}"
      echo "  # then, in a second terminal on that SSH session:"
      echo "  kubectl port-forward -n ${MONITORING_NAMESPACE} svc/monitoring-grafana 3000:80"
      echo "  # then open http://localhost:3000 on YOUR machine (user: admin)"
    else
      ssh_run "$CONTROL_IP" "helm uninstall otel -n ${MONITORING_NAMESPACE} 2>/dev/null || true"
      ssh_run "$CONTROL_IP" "helm uninstall monitoring -n ${MONITORING_NAMESPACE} 2>/dev/null || true"
      ssh_run "$CONTROL_IP" "kubectl delete namespace ${MONITORING_NAMESPACE} --ignore-not-found"
    fi
    ;;

  *)
    echo "Unknown component: $COMPONENT (expected: calico | storage | helm | monitoring)"
    exit 1
    ;;
esac

log "Done: ${ACTION} ${COMPONENT}"