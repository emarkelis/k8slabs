#!/usr/bin/env bash

set -euo pipefail

timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

log() {
    echo "[INFO] $(timestamp) $*"
}

warn() {
    echo "[WARN] $(timestamp) $*" >&2
}

fail() {
    echo "[ERROR] $(timestamp) $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 \
      || fail "Missing required command: $1"
}
