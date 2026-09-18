#!/usr/bin/env bash

set -euo pipefail

LOCAL_PATH_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"

ACTION="${1:-install}"

case "${ACTION}" in

install)

    kubectl apply -f "${LOCAL_PATH_URL}"

    kubectl patch storageclass local-path \
      -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

    ;;

remove)

    kubectl delete -f "${LOCAL_PATH_URL}" \
      --ignore-not-found=true

    ;;

upgrade)

    kubectl apply -f "${LOCAL_PATH_URL}"

    ;;

validate)

    kubectl get storageclass

    ;;

*)

    echo "Unsupported action"

    exit 1

esac
