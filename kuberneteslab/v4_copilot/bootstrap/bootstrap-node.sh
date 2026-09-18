#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../config/cluster.conf"

echo
echo "========================================="
echo " Kubernetes Lab v4 Bootstrap"
echo "========================================="
echo

echo "Hostname  : $(hostname)"
echo "Primary IP: $(hostname -I | awk '{print $1}')"
echo "Interface : ${NETWORK_INTERFACE}"
echo

#
# Operating System Validation
#

if ! grep -qi ubuntu /etc/os-release
then
    echo "ERROR: Ubuntu is required."
    exit 1
fi

echo "Ubuntu detected."

#
# Disable Firewall
#

if systemctl is-enabled ufw >/dev/null 2>&1
then

    echo
    echo "Disabling UFW..."

    sudo systemctl stop ufw || true
    sudo systemctl disable ufw || true
fi

#
# Install Runtime
#

echo
echo "Installing runtime..."
echo

"${SCRIPT_DIR}/install-containerd.sh"

#
# Install Kubernetes Components
#

echo
echo "Installing Kubernetes tools..."
echo

"${SCRIPT_DIR}/install-kubernetes.sh"

#
# Configure crictl
#

echo
echo "Configuring crictl..."
echo

sudo crictl config \
  --set runtime-endpoint=unix:///run/containerd/containerd.sock

#
# Validation
#

echo
echo "========================================="
echo " Validation"
echo "========================================="
echo

echo "Container Runtime"

sudo crictl info >/dev/null

echo " OK"

echo
echo "Containerd"

systemctl is-active containerd

echo
echo "Kubelet"

systemctl is-enabled kubelet

echo
echo "Kernel Modules"

lsmod | grep br_netfilter

echo
echo "Swap"

free -h

echo
echo "========================================="
echo " Bootstrap Complete"
echo "========================================="
echo

echo "Next Steps"

echo
echo "Control Plane:"
echo
echo "  cluster/build.sh"

echo
echo "Workers:"
echo
echo "  Wait until join-workers.sh is generated."
