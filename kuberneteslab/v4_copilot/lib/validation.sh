#!/usr/bin/env bash

set -euo pipefail

validate_containerd() {

    systemctl is-active \
        --quiet containerd
}

validate_kubelet() {

    systemctl is-enabled \
        kubelet >/dev/null
}

validate_swap() {

    ! swapon --show | grep -q .
}
