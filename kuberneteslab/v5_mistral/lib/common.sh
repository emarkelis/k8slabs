#!/bin/bash
# Common functions and variables for v4_mistral Kubernetes lab
# Source this file in all scripts: source "$(dirname "$0")/../lib/common.sh"

set -euo pipefail

# --- Load Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_CONF="${SCRIPT_DIR}/../lab.conf"

if [[ ! -f "$LAB_CONF" ]]; then
    echo "ERROR: Configuration file not found at $LAB_CONF"
    exit 1
fi

source "$LAB_CONF"

# --- Node Lists ---
ALL_NODES=("${CONTROL_IP}" "${WORKER_IPS[@]}")
ALL_HOSTNAMES=("${CONTROL_NAME}" "${WORKER_NAMES[@]}")

# --- Colors for Output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Logging Functions ---
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# --- SSH Functions ---
ssh_opts() {
    local node_ip="$1"
    echo "-i ${SSH_KEY_PATH} -o StrictHostKeyChecking=no -o ConnectTimeout=${SSH_TIMEOUT} ${SSH_USER}@${node_ip}"
}

run_ssh() {
    local node_ip="$1"
    shift
    ssh $(ssh_opts "$node_ip") "$@"
}

run_scp() {
    local node_ip="$1"
    local local_file="$2"
    local remote_path="$3"
    scp $(ssh_opts "$node_ip") "$local_file" "${SSH_USER}@${node_ip}:${remote_path}"
}

# --- Node Management Functions ---
check_ssh() {
    local node_ip="$1"
    local node_name="$2"
    if run_ssh "$node_ip" "hostname" >/dev/null 2>&1; then
        log_info "SSH access to ${node_name} (${node_ip}) is working."
        return 0
    else
        log_error "SSH access to ${node_name} (${node_ip}) failed."
        return 1
    fi
}

check_all_nodes_ssh() {
    log_info "Checking SSH access to all nodes..."
    local all_ok=true
    
    # Check control node
    check_ssh "$CONTROL_IP" "$CONTROL_NAME" || all_ok=false
    
    # Check worker nodes
    for i in "${!WORKER_IPS[@]}"; do
        check_ssh "${WORKER_IPS[$i]}" "${WORKER_NAMES[$i]}" || all_ok=false
    done
    
    if $all_ok; then
        log_success "SSH access to all nodes is working."
        return 0
    else
        log_error "SSH access to one or more nodes failed. Run 00_prepare-nodes.sh first."
        return 1
    fi
}

# --- Kubernetes Helper Functions ---
wait_for_nodes_ready() {
    local max_retries=30
    local retry_interval=10
    local all_ready=false
    
    log_info "Waiting for all nodes to be Ready (timeout: ${DEPLOY_TIMEOUT}s)..."
    
    for ((i=1; i<=max_retries; i++)); do
        local ready_count=0
        local total_nodes=3
        
        # Get node status
        local node_status
        node_status=$(run_ssh "$CONTROL_IP" "kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type==\"Ready\")].status}'" 2>/dev/null || echo "")
        
        # Count Ready nodes
        if [[ -n "$node_status" ]]; then
            ready_count=$(echo "$node_status" | tr ' ' '\n' | grep -c "True" || echo "0")
        fi
        
        if [[ "$ready_count" -eq "$total_nodes" ]]; then
            all_ready=true
            break
        fi
        
        log_info "Attempt ${i}/${max_retries}: ${ready_count}/${total_nodes} nodes are Ready."
        sleep "$retry_interval"
    done
    
    if $all_ready; then
        log_success "All nodes are Ready!"
        run_ssh "$CONTROL_IP" "kubectl get nodes -o wide"
        return 0
    else
        log_warning "Not all nodes are Ready after ${DEPLOY_TIMEOUT}s. Current status:"
        run_ssh "$CONTROL_IP" "kubectl get nodes -o wide" || true
        return 1
    fi
}

# --- File Management Functions ---
sync_scripts_to_node() {
    local node_ip="$1"
    local node_name="$2"
    local scripts_dir="${SCRIPT_DIR}/.."
    local remote_dir="/tmp/k8s_lab"
    
    log_info "Syncing scripts to ${node_name} (${node_ip})..."
    
    # Create remote directory
    run_ssh "$node_ip" "mkdir -p ${remote_dir}"
    
    # Sync all script files
    run_scp "$node_ip" "${scripts_dir}/lab.conf" "${remote_dir}/"
    run_scp "$node_ip" "${scripts_dir}/lib/common.sh" "${remote_dir}/lib/"
    run_scp "$node_ip" "${scripts_dir}/01_bootstrap-node.sh" "${remote_dir}/"
    run_scp "$node_ip" "${scripts_dir}/02_reset-node.sh" "${remote_dir}/"
    
    log_success "Scripts synced to ${node_name}."
}

# --- Validation Functions ---
validate_config() {
    log_info "Validating configuration..."
    
    # Check required variables
    local required_vars=("SSH_USER" "CONTROL_IP" "K8S_VERSION" "POD_CIDR")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log_error "Required configuration variable '$var' is not set in $LAB_CONF"
            exit 1
        fi
    done
    
    # Validate IP addresses
    for ip in "$CONTROL_IP" "${WORKER_IPS[@]}"; do
        if ! [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            log_error "Invalid IP address: $ip"
            exit 1
        fi
    done

    # Validate arrays have same length
    if [[ "${#WORKER_IPS[@]}" -ne "${#WORKER_NAMES[@]}" ]]; then
        log_error "WORKER_IPS and WORKER_NAMES arrays must have the same length"
        exit 1
    fi

    log_success "Configuration is valid."
}

# --- Utility Functions ---
print_header() {
    echo ""
    echo "=========================================="
    echo " $1"
    echo "=========================================="
    echo ""
}

print_node_list() {
    echo ""
    echo "Nodes in this lab:"
    echo "  Control: ${CONTROL_NAME} (${CONTROL_IP})"
    for i in "${!WORKER_NAMES[@]}"; do
        echo "  Worker:  ${WORKER_NAMES[$i]} (${WORKER_IPS[$i]})"
    done
    echo ""
}
