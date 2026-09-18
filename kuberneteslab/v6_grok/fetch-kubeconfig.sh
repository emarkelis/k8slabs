#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

log "Fetching kubeconfig from control plane"
scp "${ssh_opts[@]}" "${SSH_USER}@${CONTROL_IP}:.kube/config" "${SCRIPT_DIR}/kubeconfig"
ok "Saved to ${SCRIPT_DIR}/kubeconfig"
echo "export KUBECONFIG=${SCRIPT_DIR}/kubeconfig"

