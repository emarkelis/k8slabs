#!/bin/bash
# v4_mistral - Initialize the Kubernetes control plane
# Run this from your admin machine (orchestration script)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "Initializing Kubernetes Control Plane"
print_node_list

# --- Validate Configuration ---
validate_config
check_all_nodes_ssh

# --- Initialize Control Plane ---
log_info "Initializing control plane on ${CONTROL_NAME} (${CONTROL_IP})..."

# Generate kubeadm config
KUBEADM_CONFIG="/tmp/kubeadm-config.yaml"
run_ssh "$CONTROL_IP" "cat > ${KUBEADM_CONFIG} <<EOF
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${CONTROL_IP}
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  name: ${CONTROL_NAME}
---
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
controlPlaneEndpoint: ${CONTROL_IP}:6443
networking:
  podSubnet: ${POD_CIDR}
  serviceSubnet: 10.96.0.0/12
controllerManager:
  extraArgs:
    allocate-node-cidrs: "true"
EOF
"

# Run kubeadm init
log_info "Running kubeadm init..."
run_ssh "$CONTROL_IP" "sudo kubeadm init --config ${KUBEADM_CONFIG} --upload-certs"

# --- Set Up kubectl for SSH_USER ---
log_info "Setting up kubectl for ${SSH_USER}..."
run_ssh "$CONTROL_IP" "mkdir -p /home/${SSH_USER}/.kube"
run_ssh "$CONTROL_IP" "sudo cp -i /etc/kubernetes/admin.conf /home/${SSH_USER}/.kube/config"
run_ssh "$CONTROL_IP" "sudo chown ${SSH_USER}:${SSH_USER} /home/${SSH_USER}/.kube/config"

# --- Save Join Command for Workers ---
log_info "Saving join command for workers..."
JOIN_COMMAND=$(run_ssh "$CONTROL_IP" "kubeadm token create --print-join-command --ttl 24h")
JOIN_HASH=$(run_ssh "$CONTROL_IP" "openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | awk '{print \$2}'")
JOIN_TOKEN=$(echo "$JOIN_COMMAND" | grep -oP 'kubeadm join .* --token \K[^ ]+')

# Save join command and hash to temp files for workers to use
run_ssh "$CONTROL_IP" "echo '${JOIN_COMMAND}' > /tmp/kubeadm-join.sh"
run_ssh "$CONTROL_IP" "echo '${JOIN_HASH}' > /tmp/join-hash.txt"
run_ssh "$CONTROL_IP" "chmod +x /tmp/kubeadm-join.sh"

log_success "Control plane initialized on ${CONTROL_NAME}."
log_info "Join command: ${JOIN_COMMAND}"
