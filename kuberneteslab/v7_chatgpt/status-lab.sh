#!/usr/bin/env bash
# Shows node reachability and, when present, Kubernetes state.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

validate_config
start_log "status"
require_command ssh

for i in "${!ALL_IPS[@]}"; do
    ip="${ALL_IPS[$i]}"
    name="${ALL_NAMES[$i]}"

    printf '\n===== %s (%s) =====\n' "${name}" "${ip}"

    if ssh "${ssh_opts[@]}" "${SSH_USER}@${ip}" true >/dev/null 2>&1; then
        run_remote "${ip}" '
            printf "hostname: "; hostname
            printf "os: "; . /etc/os-release; printf "%s\n" "$PRETTY_NAME"
            printf "containerd: "; systemctl is-active containerd 2>/dev/null || true
            printf "kubelet: "; systemctl is-active kubelet 2>/dev/null || true
            printf "sudo: "; sudo -n true >/dev/null 2>&1 && echo yes || echo no
        '
    else
        warn "SSH unavailable."
    fi
done

printf '\n===== Kubernetes cluster =====\n'
if ssh "${ssh_opts[@]}" "${SSH_USER}@${CONTROL_IP}" \
   'test -f "$HOME/.kube/config"' >/dev/null 2>&1; then

    run_remote "${CONTROL_IP}" 'kubectl get nodes -o wide'
    printf '\nPods:\n'
    run_remote "${CONTROL_IP}" 'kubectl get pods -A'

    printf '\nStorage:\n'
    run_remote "${CONTROL_IP}" 'kubectl get storageclass'
else
    warn "No active Kubernetes admin kubeconfig found on the control node."
fi
