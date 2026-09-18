#!/bin/bash
# v4_mistral - Bootstrap a Kubernetes node: Install dependencies and prepare for kubeadm
# This script is copied to and run ON each node (control and workers)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lab.conf"

print_header "Bootstrapping Kubernetes Node"

# --- Load Node-Specific Configuration ---
# This script is run on individual nodes, so we need to determine the node's role
NODE_IP="$1"
NODE_NAME="$2"

if [[ -z "$NODE_IP" || -z "$NODE_NAME" ]]; then
    log_error "Usage: $0 <NODE_IP> <NODE_NAME>"
    exit 1
fi

log_info "Bootstrapping node: ${NODE_NAME} (${NODE_IP})"

# --- Update System and Install Dependencies ---
log_info "Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# --- Install Container Runtime (containerd) ---
log_info "Installing containerd..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Restart containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

log_success "containerd installed and configured."

# --- Install Kubernetes Components (kubelet, kubeadm, kubectl) ---
log_info "Installing Kubernetes components (${K8S_VERSION})..."

# Add Kubernetes apt repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet="${K8S_VERSION}*" kubeadm="${K8S_VERSION}*" kubectl="${K8S_VERSION}*"

# Hold versions to prevent automatic updates
sudo apt-mark hold kubelet kubeadm kubectl

log_success "Kubernetes components installed (version ${K8S_VERSION})."

# --- Disable Swap ---
log_info "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# --- Enable Kernel Modules and Sysctl Settings ---
log_info "Configuring kernel modules and sysctl..."

# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set sysctl parameters for Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

log_success "Kernel modules and sysctl settings configured."

# --- Set Hostname ---
log_info "Setting hostname to ${NODE_NAME}..."
sudo hostnamectl set-hostname "${NODE_NAME}"

# Update /etc/hosts with all nodes
log_info "Updating /etc/hosts..."

# Backup existing /etc/hosts
sudo cp /etc/hosts /etc/hosts.bak

# Build the hosts file content
HOSTS_CONTENT="127.0.0.1 localhost\n"
HOSTS_CONTENT+="${CONTROL_IP} ${CONTROL_NAME}\n"
for i in "${!WORKER_IPS[@]}"; do
    HOSTS_CONTENT+="${WORKER_IPS[$i]} ${WORKER_NAMES[$i]}\n"
done
HOSTS_CONTENT+="\n# The following lines are desirable for IPv6 capable hosts\n"
HOSTS_CONTENT+="::1 ip6-localhost ip6-loopback\n"
HOSTS_CONTENT+="fe00::0 ip6-localnet\n"
HOSTS_CONTENT+="ff00::0 ip6-mcastprefix\n"
HOSTS_CONTENT+="ff02::1 ip6-allnodes\n"
HOSTS_CONTENT+="ff02::2 ip6-allrouters\n"

# Write the hosts file
echo -e "$HOSTS_CONTENT" | sudo tee /etc/hosts >/dev/null

log_success "Hostname and /etc/hosts configured."

# --- Verify Installation ---
log_info "Verifying installation..."
containerd --version
kubelet --version
kubeadm version
kubectl version --client

log_success "Node ${NODE_NAME} is bootstrapped and ready for Kubernetes!"
