#!/usr/bin/env bash

set -euo pipefail

LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../logs" && pwd)"

mkdir -p "${LOG_DIR}"

start_log() {

    local prefix="$1"

    local logfile="${LOG_DIR}/${prefix}-$(date +%Y%m%d-%H%M%S).log"

    exec > >(tee -a "${logfile}")
    exec 2>&1

    echo "Logging to ${logfile}"
}
