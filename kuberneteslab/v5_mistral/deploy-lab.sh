#!/bin/bash
# v4_mistral - Main deployment script: Build or rebuild the Kubernetes lab
# Run this from your admin machine to deploy or redeploy the cluster

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Deploying Kubernetes Lab"
print_node_list

# --- Validate Configuration ---
validate_config
check_all_nodes_ssh

# --- Sync Scripts to All Nodes ---
log_info "Syncing scripts to all nodes..."

sync_node_scripts() {
    local node_ip="$1"
    local node_name="$2"
    local remote_dir="/tmp/k8s_lab"
    
    log_info "Syncing scripts to ${node_name}..."
    
    # Create remote directory
    run_ssh "$node_ip" "mkdir -p ${remote_dir}/lib"
    
    # Sync configuration
    run_scp "$node_ip" "${SCRIPT_DIR}/lab.conf" "${remote_dir}/"
    
    # Sync common library
    run_scp "$node_ip" "${SCRIPT_DIR}/lib/common.sh" "${remote_dir}/lib/"
    
    # Sync node scripts
    run_scp "$node_ip" "${SCRIPT_DIR}/01_bootstrap-node.sh" "${remote_dir}/"
    run_scp "$node_ip" "${SCRIPT_DIR}/02_reset-node.sh" "${remote_dir}/"
    
    log_success "Scripts synced to ${node_name}."
}

# Sync to control node
sync_node_scripts "$CONTROL_IP" "$CONTROL_NAME"

# Sync to worker nodes
for i in "${!WORKER_IPS[@]}"; do
    sync_node_scripts "${WORKER_IPS[$i]}" "${WORKER_NAMES[$i]}"
done

# --- Bootstrap and Reset All Nodes ---
log_info "Bootstrapping and resetting all nodes..."

bootstrap_and_reset_node() {
    local node_ip="$1"
    local node_name="$2"
    local remote_dir="/tmp/k8s_lab"
    
    log_info "Processing ${node_name}..."
    
    # Run bootstrap script
    run_ssh "$node_ip" "sudo bash ${remote_dir}/01_bootstrap-node.sh ${node_ip} ${node_name}"
    
    # Run reset script
    run_ssh "$node_ip" "sudo bash ${remote_dir}/02_reset-node.sh ${node_name}"
    
    log_success "${node_name} is bootstrapped and reset."
}

# Process control node
bootstrap_and_reset_node "$CONTROL_IP" "$CONTROL_NAME"

# Process worker nodes
for i in "${!WORKER_IPS[@]}"; do
    bootstrap_and_reset_node "${WORKER_IPS[$i]}" "${WORKER_NAMES[$i]}"
done

# --- Initialize Control Plane ---
log_info "Initializing control plane..."
if ! bash "${SCRIPT_DIR}/03_init-control.sh"; then
    log_error "Failed to initialize control plane."
    exit 1
fi

# --- Join Worker Nodes ---
log_info "Joining worker nodes..."
if ! bash "${SCRIPT_DIR}/04_join-workers.sh"; then
    log_error "Failed to join worker nodes."
    exit 1
fi

# --- Install Cluster Components ---
log_info "Installing cluster components..."
if ! bash "${SCRIPT_DIR}/05_cluster-components.sh"; then
    log_error "Failed to install cluster components."
    exit 1
fi

# --- Wait for Cluster Readiness ---
log_info "Waiting for cluster to be ready..."
if ! wait_for_nodes_ready; then
    log_warning "Cluster is not fully ready. Check node status manually."
fi

log_success "Kubernetes lab deployed successfully!"
log_info "Run './fetch-kubeconfig.sh' to access the cluster from your admin machine."
