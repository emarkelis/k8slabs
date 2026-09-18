#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo
echo "======================================="
echo " Kubernetes Reset"
echo "======================================="
echo

echo "1) Remove workloads only"
echo "2) Remove workloads + addons"
echo "3) Cluster reset"
echo "4) Factory reset"

echo
read -rp "Select option: " CHOICE

case "${CHOICE}" in

1)

    echo
    echo "Removing workloads..."

    kubectl delete deployment \
      --all \
      --all-namespaces \
      --ignore-not-found=true

    kubectl delete statefulset \
      --all \
      --all-namespaces \
      --ignore-not-found=true

    kubectl delete daemonset \
      --all \
      --all-namespaces \
      --ignore-not-found=true

    kubectl delete job \
      --all \
      --all-namespaces \
      --ignore-not-found=true

    ;;

2)

    echo
    echo "Removing addons..."

    "${ROOT_DIR}/addons/otel.sh" remove

    "${ROOT_DIR}/addons/monitoring.sh" remove

    "${ROOT_DIR}/addons/storage.sh" remove

    "${ROOT_DIR}/addons/calico.sh" remove

    ;;

3)

    echo
    echo "Running kubeadm reset..."

    sudo kubeadm reset -f

    rm -rf "${HOME}/.kube"

    ;;

4)

    echo
    echo "Factory reset..."

    sudo kubeadm reset -f

    sudo rm -rf \
      /etc/kubernetes \
      /etc/cni/net.d \
      /var/lib/cni \
      /var/lib/kubelet \
      /var/lib/etcd

    rm -rf "${HOME}/.kube"

    ;;

*)

    echo "Invalid option"

  * exit 1

    ;;

esac*
echo
echo "Reset complete."
