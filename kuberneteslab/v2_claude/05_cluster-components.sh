#!/bin/bash
# 05_cluster-components.sh
# Orchestration script — run on YOUR machine, not on a VM.
# Installs/removes cluster add-ons by running kubectl on the control
# node (which already has a working kubeconfig after 03_init-control.sh).
#
# Usage:
#   ./05_cluster-components.sh install calico
#   ./05_cluster-components.sh remove  storage

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DIR/lab.conf"
source "$DIR/lib/common.sh"

ACTION="${1:-}"
COMPONENT="${2:-}"

if [[ -z "$ACTION" || -z "$COMPONENT" ]]; then
  echo "Usage: $0 <install|remove> <calico|storage>"
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
  *)
    echo "Unknown component: $COMPONENT (expected: calico | storage)"
    exit 1
    ;;
esac

log "Done: ${ACTION} ${COMPONENT}"
