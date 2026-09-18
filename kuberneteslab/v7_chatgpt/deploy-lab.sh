#!/usr/bin/env bash
# Main entry point: reset + bootstrap + init + join + components.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

validate_config
start_log "deploy"
require_command ssh
require_command scp

[[ -f "${ROOT_DIR}/01_bootstrap-node.sh" ]] || die "01_bootstrap-node.sh is missing."
[[ -f "${ROOT_DIR}/02_reset-node.sh" ]] || die "02_reset-node.sh is missing."

log "============================================================"
log " Kubernetes Lab v7 - DEPLOY / REDEPLOY"
log " VMs are NOT powered off, rebooted, deleted or recreated."
log " Existing Kubernetes lab state WILL be reset first."
log "============================================================"

for i in "${!ALL_IPS[@]}"; do
    ip="${ALL_IPS[$i]}"
    name="${ALL_NAMES[$i]}"
    log "Checking ${name} (${ip})."
    check_ssh "${ip}"
    check_passwordless_sudo "${ip}"
done
ok "SSH and passwordless sudo checks passed."

TMP_REMOTE_CONFIG="$(mktemp)"
trap 'rm -f "${TMP_REMOTE_CONFIG}"' EXIT
build_remote_config "${TMP_REMOTE_CONFIG}"

for i in "${!ALL_IPS[@]}"; do
    ip="${ALL_IPS[$i]}"
    name="${ALL_NAMES[$i]}"

    log "Syncing node scripts to ${name}."
    run_remote "${ip}" "mkdir -p '${REMOTE_WORKDIR}'"

    scp_to "${ip}" "${ROOT_DIR}/01_bootstrap-node.sh" "${REMOTE_WORKDIR}/01_bootstrap-node.sh"
    scp_to "${ip}" "${ROOT_DIR}/02_reset-node.sh" "${REMOTE_WORKDIR}/02_reset-node.sh"
    scp_to "${ip}" "${TMP_REMOTE_CONFIG}" "${REMOTE_WORKDIR}/lab.conf.tmp"

    run_remote "${ip}" \
        "mv '${REMOTE_WORKDIR}/lab.conf.tmp' '${REMOTE_WORKDIR}/lab.conf' &&
         chmod 600 '${REMOTE_WORKDIR}/lab.conf' &&
         chmod 700 '${REMOTE_WORKDIR}/01_bootstrap-node.sh' '${REMOTE_WORKDIR}/02_reset-node.sh'"
done

for i in "${!ALL_IPS[@]}"; do
    ip="${ALL_IPS[$i]}"
    name="${ALL_NAMES[$i]}"

    log "Resetting Kubernetes state on ${name}."
    run_remote "${ip}" "bash '${REMOTE_WORKDIR}/02_reset-node.sh'"
done
ok "Existing Kubernetes state removed."

for i in "${!ALL_IPS[@]}"; do
    ip="${ALL_IPS[$i]}"
    name="${ALL_NAMES[$i]}"

    log "Bootstrapping ${name}."
    run_remote "${ip}" "TARGET_HOSTNAME='${name}' bash '${REMOTE_WORKDIR}/01_bootstrap-node.sh'"
done
ok "All nodes bootstrapped."

bash "${SCRIPT_DIR}/03_init-control.sh"
bash "${SCRIPT_DIR}/04_join-workers.sh"
bash "${SCRIPT_DIR}/05_cluster-components.sh"

log "Final validation."
run_remote "${CONTROL_IP}" 'kubectl get nodes -o wide'
run_remote "${CONTROL_IP}" 'kubectl get storageclass'

ok "============================================================"
ok " Kubernetes Lab v7 deployment completed successfully."
ok "============================================================"
