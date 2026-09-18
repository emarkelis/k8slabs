#!/bin/bash
# v4_mistral - Install cluster components (Calico CNI and local-path-provisioner)
# Run this from your admin machine (orchestration script)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Installing Cluster Components"
print_node_list

# --- Validate Configuration ---
validate_config
check_all_nodes_ssh

# --- Install Calico CNI ---
log_info "Installing Calico CNI (version ${CALICO_VERSION})..."

# Download Calico manifest
CALICO_MANIFEST="/tmp/calico.yaml"
run_ssh "$CONTROL_IP" "curl -fsSL https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml -o ${CALICO_MANIFEST}"

# Replace default pod CIDR with our configured one
run_ssh "$CONTROL_IP" "sed -i 's/192.168.0.0\/16/${POD_CIDR}/g' ${CALICO_MANIFEST}"

# Apply Calico manifest
if run_ssh "$CONTROL_IP" "kubectl apply -f ${CALICO_MANIFEST}" 2>&1; then
    log_success "Calico CNI installed."
else
    log_error "Failed to install Calico CNI."
    exit 1
fi

# --- Install Local-Path-Provisoner (Default StorageClass) ---
log_info "Installing local-path-provisioner (version ${LOCAL_PATH_VERSION})..."

# Create namespace
run_ssh "$CONTROL_IP" "kubectl create namespace local-path-storage --dry-run=client -o yaml | kubectl apply -f -" || true

# Download and apply local-path-provisioner manifest
LOCAL_PATH_MANIFEST="/tmp/local-path-provisioner.yaml"
run_ssh "$CONTROL_IP" "curl -fsSL https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner/releases/download/${LOCAL_PATH_VERSION}/local-path-provisioner.yaml -o ${LOCAL_PATH_MANIFEST}"

# Apply with our storage class name
run_ssh "$CONTROL_IP" "sed -i 's/name: local-path/name: local-path\n  annotations:\n    storageclass.kubernetes.io\/is-default-class: \"true\"/g' ${LOCAL_PATH_MANIFEST}"

if run_ssh "$CONTROL_IP" "kubectl apply -f ${LOCAL_PATH_MANIFEST}" 2>&1; then
    log_success "local-path-provisioner installed with default StorageClass."
else
    log_error "Failed to install local-path-provisioner."
    exit 1
fi

# --- Set Default StorageClass ---
log_info "Setting local-path as default StorageClass..."
run_ssh "$CONTROL_IP" "kubectl patch storageclass local-path -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'" || true

log_success "Cluster components installed successfully."
