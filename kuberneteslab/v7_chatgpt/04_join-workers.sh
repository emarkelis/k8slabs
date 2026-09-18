#!/usr/bin/env bash
# Generates a fresh kubeadm join command and joins every configured worker.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

validate_config

log "Creating a short-lived worker join token."
JOIN_CMD="$(run_remote "${CONTROL_IP}" "sudo kubeadm token create --ttl '${JOIN_TOKEN_TTL}' --print-join-command")"
[[ -n "${JOIN_CMD}" ]] || die "kubeadm did not return a join command."

for i in "${!WORKER_IPS[@]}"; do
    ip="${WORKER_IPS[$i]}"
    name="${WORKER_NAMES[$i]}"

    log "Joining ${name} (${ip})."
    run_remote "${ip}" \
        "sudo ${JOIN_CMD} --node-name '${name}' --cri-socket unix:///run/containerd/containerd.sock"

    run_remote "${CONTROL_IP}" "kubectl get node '${name}' -o wide"
    ok "${name} joined."
done

ok "All configured workers have joined."
