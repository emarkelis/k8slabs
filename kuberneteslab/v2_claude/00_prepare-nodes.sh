#!/bin/bash
# 00_prepare-nodes.sh
#
# Run this ONCE, before your first deploy, from your own machine
# (not from inside any of the VMs).
#
# Using the password in lab.conf, it:
#   1. generates an SSH key locally if SSH_KEY doesn't exist yet
#   2. copies that key to control/worker01/worker03
#   3. enables passwordless sudo for SSH_USER on all three
#
# After this succeeds, every other script logs in with the key and
# never needs the password again. Blank SSH_PASSWORD in lab.conf
# afterwards if you like — nothing else reads it.

set -e
DIR="$(cd "$(dirname -- "$0")" && pwd)"
source "$DIR/lab.conf"

if [[ -z "$SSH_PASSWORD" ]]; then
  echo "SSH_PASSWORD is empty in lab.conf — nothing to do."
  echo "If key-based SSH to all three nodes already works, you're set: run ./deploy-lab.sh"
  exit 0
fi

if ! command -v sshpass &>/dev/null; then
  echo "This script needs 'sshpass'. Install it first:"
  echo "  sudo apt install sshpass"
  exit 1
fi

if [[ ! -f "$SSH_KEY" ]]; then
  echo "No SSH key at $SSH_KEY — generating one..."
  mkdir -p "$(dirname "$SSH_KEY")"
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "k8s-lab"
fi

ALL_NAMES=("$CONTROL_NAME" "${WORKER_NAMES[@]}")
ALL_IPS=("$CONTROL_IP" "${WORKER_IPS[@]}")

for i in "${!ALL_IPS[@]}"; do
  NAME="${ALL_NAMES[$i]}"
  IP="${ALL_IPS[$i]}"
  echo
  echo "=== ${NAME} (${IP}) ==="

  echo "-> copying SSH key..."
  sshpass -p "$SSH_PASSWORD" ssh-copy-id \
    -o StrictHostKeyChecking=accept-new -i "${SSH_KEY}.pub" \
    "${SSH_USER}@${IP}"

  echo "-> enabling passwordless sudo for ${SSH_USER}..."
  sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=accept-new "${SSH_USER}@${IP}" "
    echo '${SSH_PASSWORD}' | sudo -S bash -c '
      echo \"${SSH_USER} ALL=(ALL) NOPASSWD:ALL\" > /etc/sudoers.d/90-k8s-lab
      chmod 440 /etc/sudoers.d/90-k8s-lab
    '
  "
  echo "-> ${NAME} ready."
done

echo
echo "All three nodes are prepared. Next: ./deploy-lab.sh"
