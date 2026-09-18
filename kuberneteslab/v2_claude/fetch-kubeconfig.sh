#!/bin/bash
# fetch-kubeconfig.sh
# Copies the cluster's kubeconfig from the control node down to
# ./kubeconfig, so you can run kubectl from your own machine instead
# of SSHing into control every time.

set -e
DIR="$(cd "$(dirname -- "$0")" && pwd)"
source "$DIR/lab.conf"
source "$DIR/lib/common.sh"

scp_from "$CONTROL_IP" "/home/${SSH_USER}/.kube/config" "$DIR/kubeconfig"

echo "Saved to $DIR/kubeconfig"
echo "Use it with:"
echo "  export KUBECONFIG=$DIR/kubeconfig"
echo "  kubectl get nodes"
