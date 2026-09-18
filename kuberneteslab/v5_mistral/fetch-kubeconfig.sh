#!/bin/bash
# v4_mistral - Fetch kubeconfig from control node to your admin machine
# Run this from your admin machine to access the cluster with kubectl

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Fetching kubeconfig"

# --- Validate Configuration ---
validate_config
check_all_nodes_ssh

# --- Fetch kubeconfig ---
log_info "Fetching kubeconfig from ${CONTROL_NAME}..."

KUBECONFIG_LOCAL="${SCRIPT_DIR}/kubeconfig"
run_scp "$CONTROL_IP" "/home/${SSH_USER}/.kube/config" "${KUBECONFIG_LOCAL}"

if [[ -f "$KUBECONFIG_LOCAL" ]]; then
    log_success "kubeconfig saved to: ${KUBECONFIG_LOCAL}"
    log_info "To use kubectl from your admin machine, run:"
    log_info "  export KUBECONFIG=${KUBECONFIG_LOCAL}"
    log_info "  kubectl get nodes"
else
    log_error "Failed to fetch kubeconfig from ${CONTROL_NAME}."
    exit 1
fi
