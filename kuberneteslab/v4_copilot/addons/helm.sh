#!/usr/bin/env bash

set -euo pipefail

ACTION="${1:-install}"

case "${ACTION}" in

install)

    curl -fsSL \
    https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | bash

    ;;

remove)

    sudo rm -f /usr/local/bin/helm

    ;;

upgrade)

    curl -fsSL \
    https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    | bash

    ;;

validate)

    helm version

    ;;

*)

    echo "Unsupported action"

    exit 1

esac
