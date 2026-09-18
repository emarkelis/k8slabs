#!/usr/bin/env bash
# Copies the control-plane kubeconfig to the local lab directory.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

validate_config
require_command ssh

mkdir -p "${ROOT_DIR}/.secrets"
chmod 700 "${ROOT_DIR}/.secrets"

DEST="${ROOT_DIR}/.secrets/kubeconfig"
log "Fetching kubeconfig from ${CONTROL_NAME} (${CONTROL_IP})."

run_remote "${CONTROL_IP}" 'sudo cat /etc/kubernetes/admin.conf' > "${DEST}.tmp"
chmod 600 "${DEST}.tmp"
mv -f "${DEST}.tmp" "${DEST}"

if command -v kubectl >/dev/null 2>&1; then
    kubectl --kubeconfig="${DEST}" config set-cluster kubernetes \
        --server="https://${CONTROL_IP}:6443" >/dev/null
fi

echo
ok "Saved kubeconfig to ${DEST}"
echo "Use it with:"
echo "  export KUBECONFIG='${DEST}'"
echo "  kubectl get nodes -o wide"
