#!/usr/bin/env bash
# Wipe Kubernetes state on all nodes — VMs stay running
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

log "=== Kubernetes Lab v6_grok — reset ==="

for i in "${!ALL_IPS[@]}"; do
  ip="${ALL_IPS[$i]}"
  name="${ALL_NAMES[$i]}"
  log "Resetting ${name} (${ip})"
  # Ensure the reset script is present
  run_remote "${ip}" "mkdir -p ${REMOTE_WORKDIR}"
  scp_to "${ip}" "${SCRIPT_DIR}/02_reset-node.sh" "${REMOTE_WORKDIR}/"
  run_remote "${ip}" "bash ${REMOTE_WORKDIR}/02_reset-node.sh"
  ok "${name} reset"
done

ok "=== Cluster wiped. VMs remain operational. ==="
