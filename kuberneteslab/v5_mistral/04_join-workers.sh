#!/bin/bash
# v4_mistral - Join worker nodes to the Kubernetes cluster
# Run this from your admin machine (orchestration script)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Joining Worker Nodes to Kubernetes Cluster"
print_node_list

# --- Validate Configuration ---
validate_config
check_all_nodes_ssh

# --- Get Join Command from Control Plane ---
log_info "Fetching join command from control plane..."
JOIN_COMMAND=$(run_ssh "$CONTROL_IP" "cat /tmp/kubeadm-join.sh" 2>/dev/null || echo "")

if [[ -z "$JOIN_COMMAND" ]]; then
    log_error "Join command not found on control plane. Run 03_init-control.sh first."
    exit 1
fi

log_info "Join command: ${JOIN_COMMAND}"

# --- Join Each Worker Node ---
join_worker() {
    local worker_ip="$1"
    local worker_name="$2"
    
    log_info "Joining ${worker_name} (${worker_ip})..."
    
    # Copy join script to worker
    local join_script="/tmp/kubeadm-join.sh"
    run_scp "$worker_ip" "<(echo "$JOIN_COMMAND")" "${join_script}"
    run_ssh "$worker_ip" "chmod +x ${join_script}"
    
    # Execute join command
    if run_ssh "$worker_ip" "sudo ${join_script}" 2>&1; then
        log_success "${worker_name} joined the cluster successfully."
        return 0
    else
        log_error "Failed to join ${worker_name}. Retrying with fresh token..."
        # Regenerate join command and retry
        JOIN_COMMAND=$(run_ssh "$CONTROL_IP" "kubeadm token create --print-join-command --ttl 24h")
        run_ssh "$worker_ip" "echo '${JOIN_COMMAND}' > ${join_script} && chmod +x ${join_script}"
        if run_ssh "$worker_ip" "sudo ${join_script}" 2>&1; then
            log_success "${worker_name} joined the cluster on retry."
            return 0
        else
            log_error "Failed to join ${worker_name} after retry."
            return 1
        fi
    fi
}

# --- Main Execution ---
for i in "${!WORKER_IPS[@]}"; do
    join_worker "${WORKER_IPS[$i]}" "${WORKER_NAMES[$i]}"
done

log_success "All worker nodes joined the cluster."
