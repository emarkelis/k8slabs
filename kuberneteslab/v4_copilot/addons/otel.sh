#!/usr/bin/*nv bash

set -euo pipefail

MONITO*ING_NS="monitoring"

ACTION="${1:-*nstall}"

install_otel() {

    he*m repo add open-telemetry \
      *ttps://open-telemetry.github.io/op*ntelemetry-helm-charts

    helm r*po update

    kubectl create name*pace "${MONITORING_NS}" \
      --*ry-run=client \
      -o yaml \
  *   | kubectl apply -f -

    helm *pgrade \
      --install otel \
  *   open-telemetry/opentelemetry-co*lector \
      -n "${MONITORING_NS*"
}

remove_otel() {

    helm uni*stall otel \
      -n "${MONITORIN*_NS}" \
      || true
}

validate_*tel() {

    kubectl get pods \
  *   -n "${MONITORING_NS}" \
      |*grep otel || true
}

case "${ACTIO*}" in

install)

    install_otel
*    ;;

remove)

    remove_otel

*   ;;

upgrade)

    install_otel
*    ;;

validate)

    validate_ot*l

    ;;

*)

    exit 1

esac
``*
