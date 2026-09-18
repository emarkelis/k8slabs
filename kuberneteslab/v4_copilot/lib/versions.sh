#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../config/versions.conf"

resolve_kubernetes_version() {

    if [[ "${VERSION_MODE}" == "latest" ]]
    then
        curl -fsSL \
        https://dl.k8s.io/release/stable.txt
    else
        echo "${K8S_VERSION}"
    fi
}
