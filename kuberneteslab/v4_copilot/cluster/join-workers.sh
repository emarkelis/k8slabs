#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${ROOT_DIR}/config/cluster.conf"
source "${ROOT_DIR}/config/credentials.conf"

echo
echo "======================================="
echo " Worker Join Automation"
echo "======================================="

JOIN_CMD=$(sudo kubeadm token create \
  --print-join-command)

echo
echo "Join Command:"
echo "${JOIN_CMD}"
echo

for i in "${!WORKER_HOSTS[@]}"
do

    HOST="${WORKER_HOSTS[$i]}"
    IP="${WORKER_IPS[$i]}"

    echo
    echo "Joining ${HOST} (${IP})"

    ssh \
      -i "${SSH_KEY}" \
      ${SSH_OPTIONS} \
      "${SSH_USER}@${IP}" \
      "sudo kubeadm reset -f"

    ssh \
      -i "${SSH_KEY}" \
      ${SSH_OPTIONS} \
      "${SSH_USER}@${IP}" \
      "sudo ${JOIN_CMD}"

done

echo
echo "Waiting for nodes to register..."

sleep 30

kubectl get nodes -o wide

echo
echo "Worker join complete."
`
