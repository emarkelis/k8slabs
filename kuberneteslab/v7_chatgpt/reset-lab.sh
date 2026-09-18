#!/usr/bin/env bash
# Reset Kubernetes on all nodes; VMs remain running.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

validate_config
start_log "reset"
require_command ssh
require_command scp

log "This removes Kubernetes lab state from every configured node."
log "The Ubuntu VMs remain powered on and are not rebooted."
if [[ "${RESET_LOCAL_PATH_DATA:-true}" == "true" ]]; then
    warn "Local-path PersistentVolume data will also be removed."
fi

TMP_REMOTE_CONFIG="$(mktemp)"
trap 'rm -f "${TMP_REMOTE_CONFIG}"' EXIT
build_remote_config "${TMP_REMOTE_CONFIG}"

for i in "${!ALL_IPS[@]}"; do
    ip="${ALL_IPS[$i]}"
    name="${ALL_NAMES[$i]}"

    check_ssh "${ip}"
    check_passwordless_sudo "${ip}"

    log "Preparing reset script on ${name} (${ip})."
    run_remote "${ip}" "mkdir -p '${REMOTE_WORKDIR}'"
    scp_to "${ip}" "${ROOT_DIR}/02_reset-node.sh" "${REMOTE_WORKDIR}/02_reset-node.sh"
    scp_to "${ip}" "${TMP_REMOTE_CONFIG}" "${REMOTE_WORKDIR}/lab.conf.tmp"

    run_remote "${ip}" \
        "mv '${REMOTE_WORKDIR}/lab.conf.tmp' '${REMOTE_WORKDIR}/lab.conf' &&
         chmod 600 '${REMOTE_WORKDIR}/lab.conf' &&
         chmod 700 '${REMOTE_WORKDIR}/02_reset-node.sh' &&
         bash '${REMOTE_WORKDIR}/02_reset-node.sh'"

    ok "${name} reset."
done

ok "Lab reset complete. VMs remain operational. Run ./deploy-lab.sh to rebuild the cluster."
