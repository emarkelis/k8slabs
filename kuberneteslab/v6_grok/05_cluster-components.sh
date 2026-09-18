#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/common.sh"

log "Installing Calico"
run_remote "${CONTROL_IP}" "kubectl apply -f ${CALICO_URL}"

log "Installing local-path StorageClass"
run_remote "${CONTROL_IP}" "kubectl apply -f ${LOCAL_PATH_URL}"
run_remote "${CONTROL_IP}" "kubectl patch storageclass local-path -p '{\"metadata\":{\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'" || true

log "Waiting for nodes to become Ready (up to 3 minutes)"
for _ in {1..36}; do
  READY=$(run_remote "${CONTROL_IP}" "kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready ' || true")
  if [[ "${READY}" -eq 3 ]]; then
    ok "All 3 nodes are Ready"
    run_remote "${CONTROL_IP}" "kubectl get nodes -o wide"
    exit 0
  fi
  sleep 5
done

warn "Not all nodes Ready yet — current status:"
run_remote "${CONTROL_IP}" "kubectl get nodes -o wide" || true
