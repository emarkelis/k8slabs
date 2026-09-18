#!/usr/bin/env bash
# Main entry point — fully idempotent build / rebuild
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

log "=== Kubernetes Lab v6_grok — deploy ==="

# 1. Sanity check SSH
for ip in "${ALL_IPS[@]}"; do
  check_ssh "${ip}"
done
ok "SSH connectivity OK"

# 2. Sync scripts + config to every node
for i in "${!ALL_IPS[@]}"; do
  ip="${ALL_IPS[$i]}"
  name="${ALL_NAMES[$i]}"
  log "Syncing files to ${name}"
  run_remote "${ip}" "mkdir -p ${REMOTE_WORKDIR}"
  scp_to "${ip}" "${SCRIPT_DIR}/lab.conf" "${REMOTE_WORKDIR}/"
  scp_to "${ip}" "${SCRIPT_DIR}/01_bootstrap-node.sh" "${REMOTE_WORKDIR}/"
  scp_to "${ip}" "${SCRIPT_DIR}/02_reset-node.sh" "${REMOTE_WORKDIR}/"
done

# 3. Bootstrap all nodes
for i in "${!ALL_IPS[@]}"; do
  ip="${ALL_IPS[$i]}"
  name="${ALL_NAMES[$i]}"
  log "Bootstrapping ${name}"
  run_remote "${ip}" "bash ${REMOTE_WORKDIR}/01_bootstrap-node.sh"
done

# 4. Reset all nodes (clean slate)
for i in "${!ALL_IPS[@]}"; do
  ip="${ALL_IPS[$i]}"
  name="${ALL_NAMES[$i]}"
  log "Resetting ${name}"
  run_remote "${ip}" "bash ${REMOTE_WORKDIR}/02_reset-node.sh"
done

# 5. Init control plane
bash "${SCRIPT_DIR}/03_init-control.sh"

# 6. Join workers
bash "${SCRIPT_DIR}/04_join-workers.sh"

# 7. Install components + wait for Ready
bash "${SCRIPT_DIR}/05_cluster-components.sh"

ok "=== Lab deployed successfully ==="
