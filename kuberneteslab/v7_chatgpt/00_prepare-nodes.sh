#!/usr/bin/env bash
# One-time access preparation. Safe to run repeatedly.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

validate_config
start_log "prepare"
require_command ssh
require_command ssh-keygen

log "Preparing ${#ALL_IPS[@]} nodes for key-based SSH and passwordless sudo."

if [[ ! -f "${SSH_KEY_PATH}" ]]; then
    log "Generating SSH key: ${SSH_KEY_PATH}"
    mkdir -p "$(dirname "${SSH_KEY_PATH}")"
    chmod 700 "$(dirname "${SSH_KEY_PATH}")"
    ssh-keygen -t ed25519 -N "" -f "${SSH_KEY_PATH}" -C "k8s-lab-v7" >/dev/null
fi
chmod 600 "${SSH_KEY_PATH}"
chmod 644 "${SSH_KEY_PATH}.pub"

for i in "${!ALL_IPS[@]}"; do
    ip="${ALL_IPS[$i]}"
    name="${ALL_NAMES[$i]}"

    log "Checking ${name} (${ip})."

    key_ok=false
    sudo_ok=false

    if ssh "${ssh_opts[@]}" "${SSH_USER}@${ip}" true >/dev/null 2>&1; then
        key_ok=true
    fi

    if [[ "${key_ok}" == true ]] &&        ssh "${ssh_opts[@]}" "${SSH_USER}@${ip}" 'sudo -n true' >/dev/null 2>&1; then
        sudo_ok=true
    fi

    if [[ "${key_ok}" != true ]]; then
        [[ -n "${SSH_PASSWORD:-}" ]] ||             die "No SSH key access to ${name} and SSH_PASSWORD is empty. Set a temporary password in lab.conf and rerun."
        require_command sshpass
        require_command ssh-copy-id

        log "Installing SSH key on ${name}."
        SSHPASS="${SSH_PASSWORD}" sshpass -e ssh-copy-id             -o "StrictHostKeyChecking=${SSH_STRICT_HOST_KEY_CHECKING:-accept-new}"             -o "ConnectTimeout=${SSH_CONNECT_TIMEOUT:-10}"             -i "${SSH_KEY_PATH}.pub"             "${SSH_USER}@${ip}" >/dev/null
    else
        ok "SSH key access already works on ${name}."
    fi

    if [[ "${sudo_ok}" != true ]]; then
        [[ -n "${SSH_PASSWORD:-}" ]] ||             die "Passwordless sudo is not configured on ${name} and SSH_PASSWORD is empty."

        require_command sshpass
        log "Configuring passwordless sudo on ${name}."

        # The password is supplied through stdin to sudo and through the
        # SSHPASS environment variable to sshpass. It is not embedded in the
        # remote command line.
        remote_sudo_cmd="sudo -S -p '' sh -c 'printf \"%s ALL=(ALL) NOPASSWD:ALL\\n\" \"${SSH_USER}\" > /etc/sudoers.d/k8s-lab && chmod 440 /etc/sudoers.d/k8s-lab && visudo -cf /etc/sudoers.d/k8s-lab >/dev/null'"
        printf '%s\n' "${SSH_PASSWORD}" | \
            SSHPASS="${SSH_PASSWORD}" sshpass -e ssh \
            "${ssh_opts[@]}" "${SSH_USER}@${ip}" "${remote_sudo_cmd}"
    else
        ok "Passwordless sudo already works on ${name}."
    fi

    ssh "${ssh_opts[@]}" "${SSH_USER}@${ip}" 'sudo -n true' >/dev/null 2>&1 ||         die "Passwordless sudo verification failed on ${name}."

    ok "${name} is ready."
done

warn "Remove SSH_PASSWORD from lab.conf after preparation. Normal operations use the SSH key only."
ok "Node preparation complete."
