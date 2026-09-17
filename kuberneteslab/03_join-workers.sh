#!/bin/bash

set -e

echo "Generating join command..."

JOIN_CMD=$(kubeadm token create --print-join-command)

echo
echo "Run this command on worker01 and worker02:"
echo
echo "$JOIN_CMD"
echo

echo "$JOIN_CMD" > /tmp/kubeadm-join.sh

chmod +x /tmp/kubeadm-join.sh

echo "Saved to /tmp/kubeadm-join.sh"
