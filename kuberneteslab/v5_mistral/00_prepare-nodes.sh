#!/bin/bash
# v4_mistral - One-time node preparation: Set up SSH keys and passwordless sudo
# Run this ONCE from your admin machine before deploying the lab

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Preparing Nodes for Kubernetes Lab"
print_node_list

# --- Validate Configuration ---
if [[ -z "$SSH_PASSWORD" ]]; then
    log_error "SSH_PASSWORD is required for this script. Edit lab.conf and try again."
    exit 1
fi

# --- Install sshpass if not available ---
if ! command -v sshpass &>/dev/null; then
    log_info "Installing sshpass..."
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y sshpass
    elif command -v brew &>/dev/null; then
        brew install sshpass
    else
        log_error "sshpass is required. Install it manually and retry."
        exit 1
    fi
fi

# --- Generate SSH Key if it doesn't exist ---
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    log_info "Generating new SSH key at $SSH_KEY_PATH..."
    ssh-keygen -t rsa -b 4096 -N "" -f "$SSH_KEY_PATH"
    chmod 600 "$SSH_KEY_PATH"
fi

# --- Prepare Each Node ---
prepare_node() {
    local node_ip="$1"
    local node_name="$2"
    
    log_info "Preparing ${node_name} (${node_ip})..."
    
    # Test SSH with password
    if ! sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "${SSH_USER}@${node_ip}" "hostname" >/dev/null 2>&1; then
        log_error "Failed to SSH to ${node_name} with password. Check credentials."
        return 1
    fi
    
    # Install SSH public key
    sshpass -p "$SSH_PASSWORD" ssh-copy-id -i "${SSH_KEY_PATH}.pub" -o StrictHostKeyChecking=no \
        "${SSH_USER}@${node_ip}" 2>/dev/null || true
    
    # Enable passwordless sudo
    sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "${SSH_USER}@${node_ip}" "echo '${SSH_USER} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/${SSH_USER}-nopasswd >/dev/null"
    
    # Test SSH without password
    if ssh $(ssh_opts "$node_ip") "hostname" >/dev/null 2>&1; then
        log_success "${node_name} is ready (SSH key + passwordless sudo)."
        return 0
    else
        log_error "Failed to set up passwordless SSH for ${node_name}."
        return 1
    fi
}

# --- Main Execution ---
log_info "Setting up SSH keys and passwordless sudo on all nodes..."

# Prepare control node
prepare_node "$CONTROL_IP" "$CONTROL_NAME"

# Prepare worker nodes
for i in "${!WORKER_IPS[@]}"; do
    prepare_node "${WORKER_IPS[$i]}" "${WORKER_NAMES[$i]}"
done

log_success "All nodes are prepared!"
log_warning "⚠️  Security Reminder: Blank SSH_PASSWORD in lab.conf after this succeeds."
log_info "Next step: Run ./deploy-lab.sh to deploy the cluster."
