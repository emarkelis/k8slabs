#!/bin/bash
# v4_mistral - Reset the Kubernetes lab: Wipe all Kubernetes state
# Run this from your admin machine to reset the cluster (VMs remain running)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Resetting Kubernetes Lab"
print_node_list

# --- Validate Configuration ---
validate_config
check_all_nodes_ssh

# --- Sync Reset Script to All Nodes ---
log_info "Syncing reset script to all nodes..."

sync_reset_script() {
    local node_ip="$1"
    local node_name="$2"
    local remote_dir="/tmp/k8s_lab"
    
    log_info "Syncing reset script to ${node_name}..."
    
    # Create remote directory
    run_ssh "$node_ip" "mkdir -p ${remote_dir}"
    
    # Sync configuration
    run_scp "$node_ip" "${SCRIPT_DIR}/lab.conf" "${remote_dir}/"
    
    # Sync reset script
    run_scp "$node_ip" "${SCRIPT_DIR}/02_reset-node.sh" "${remote_dir}/"
    
    log_success "Reset script synced to ${node_name}."
}

# Sync to control node
sync_reset_script "$CONTROL_IP" "$CONTROL_NAME"

# Sync to worker nodes
for i in "${!WORKER_IPS[@]}"; do
    sync_reset_script "${WORKER_IPS[$i]}" "${WORKER_NAMES[$i]}"
done

# --- Reset All Nodes ---
log_info "Resetting all nodes..."

reset_node() {
    local node_ip="$1"
    local node_name="$2"
    local remote_dir="/tmp/k8s_lab"
    
    log_info "Resetting ${node_name}..."
    
    # Run reset script
    run_ssh "$node_ip" "sudo bash ${remote_dir}/02_reset-node.sh ${node_name}"
    
    log_success "${node_name} is reset."
}

# Reset control node
reset_node "$CONTROL_IP" "$CONTROL_NAME"

# Reset worker nodes
for i in "${!WORKER_IPS[@]}"; do
    reset_node "${WORKER_IPS[$i]}" "${WORKER_NAMES[$i]}"
done

log_success "Kubernetes lab reset successfully!"
log_info "All Kubernetes state has been wiped. VMs remain running."
log_info "Run './deploy-lab.sh' to redeploy the cluster."
