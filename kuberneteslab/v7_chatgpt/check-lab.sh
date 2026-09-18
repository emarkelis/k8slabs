#!/usr/bin/env bash
# Local static/preflight validation for v7.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

validate_config
require_command bash
require_command ssh
require_command scp
require_command ssh-keygen

for f in "${SCRIPT_DIR}"/*.sh "${SCRIPT_DIR}"/lib/*.sh; do
    bash -n "${f}"
done

TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT
build_remote_config "${TMP}"

if grep -q 'SSH_PASSWORD' "${TMP}"; then
    die "Remote configuration unexpectedly contains SSH_PASSWORD."
fi

if ! grep -q 'CONTROL_IP' "${TMP}"; then
    die "Remote configuration is missing CONTROL_IP."
fi

ok "Configuration validation passed."
ok "All v7 shell scripts pass bash -n."
ok "Remote configuration is password-free."
echo
echo "To test live connectivity, run: ./status-lab.sh"
