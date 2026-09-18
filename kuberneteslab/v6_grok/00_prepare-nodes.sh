#!/usr/bin/env bash
# One-time: install SSH key + enable passwordless sudo on all nodes
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

if [[ -z "${SSH_PASSWORD}" ]]; then
  warn "SSH_PASSWORD is empty. Assuming key-based access + passwordless sudo already exist."
  exit 0
fi

if [[ ! -f "${SSH_KEY}" ]]; then
  log "Generating SSH key ${SSH_KEY}"
  ssh-keygen -t ed25519 -N "" -f "${SSH_KEY}" -C "k8s-lab"
fi

PUB_KEY=$(cat "${SSH_KEY}.pub")

for i in "${!ALL_IPS[@]}"; do
  ip="${ALL_IPS[$i]}"
  name="${ALL_NAMES[$i]}"
  log "Preparing ${name} (${ip}) …"

  # Install key (using password via sshpass if available)
  if command -v sshpass &>/dev/null; then
    sshpass -p "${SSH_PASSWORD}" ssh-copy-id -o StrictHostKeyChecking=no -i "${SSH_KEY}.pub" "${SSH_USER}@${ip}" || true
  else
    warn "sshpass not found — please run: ssh-copy-id -i ${SSH_KEY}.pub ${SSH_USER}@${ip}"
  fi

  # Enable passwordless sudo
  run_remote "${ip}" "echo '${SSH_USER} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/k8s-lab >/dev/null && sudo chmod 440 /etc/sudoers.d/k8s-lab"
  ok "${name} ready"
done

log "Preparation complete. You can now blank SSH_PASSWORD in lab.conf."
