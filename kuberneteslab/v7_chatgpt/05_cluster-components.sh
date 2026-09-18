#!/usr/bin/env bash
# Installs the minimal lab CNI and dynamic local storage.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"

validate_config

CALICO_FILE="${REMOTE_WORKDIR}/calico.yaml"
LOCAL_PATH_FILE="${REMOTE_WORKDIR}/local-path-storage.yaml"

log "Downloading Calico ${CALICO_VERSION}."
run_remote "${CONTROL_IP}" "curl -fsSL '${CALICO_URL}' -o '${CALICO_FILE}'"

# The v3.32.2 manifest documents CALICO_IPV4POOL_CIDR as the default pool to
# create on first startup, and it must fall inside Kubernetes --cluster-cidr.
# Enable the commented example and set it to the configured pod CIDR before
# applying the manifest.
log "Setting Calico IPv4 pool to ${POD_CIDR}."
run_remote "${CONTROL_IP}" \
    "sudo awk -v cidr='${POD_CIDR}' '
        /^[[:space:]]*# - name: CALICO_IPV4POOL_CIDR[[:space:]]*$/ {
            match(\$0,/^[[:space:]]*/); indent=substr(\$0,RSTART,RLENGTH)
            print indent "- name: CALICO_IPV4POOL_CIDR"
            getline
            print indent "  value: \\\"" cidr "\\\""
            next
        }
        { print }
     ' '${CALICO_FILE}' > '${CALICO_FILE}.tmp' &&
     sudo mv '${CALICO_FILE}.tmp' '${CALICO_FILE}'"

if ! run_remote "${CONTROL_IP}" "grep -q 'name: CALICO_IPV4POOL_CIDR' '${CALICO_FILE}'"; then
    die "Calico manifest did not contain CALICO_IPV4POOL_CIDR in the expected form."
fi

log "Installing Calico."
run_remote "${CONTROL_IP}" "kubectl apply -f '${CALICO_FILE}'"
run_remote "${CONTROL_IP}" "kubectl -n kube-system rollout status daemonset/calico-node --timeout=10m"
run_remote "${CONTROL_IP}" "kubectl -n kube-system rollout status deployment/calico-kube-controllers --timeout=10m"

log "Downloading and installing local-path provisioner ${LOCAL_PATH_VERSION}."
run_remote "${CONTROL_IP}" "curl -fsSL '${LOCAL_PATH_URL}' -o '${LOCAL_PATH_FILE}'"
run_remote "${CONTROL_IP}" "kubectl apply -f '${LOCAL_PATH_FILE}'"
run_remote "${CONTROL_IP}" "kubectl -n local-path-storage rollout status deployment/local-path-provisioner --timeout=5m"

if [[ "${DEFAULT_STORAGE_CLASS}" == "true" ]]; then
    log "Marking local-path as the default StorageClass."
    run_remote "${CONTROL_IP}" \
        "kubectl annotate storageclass local-path storageclass.kubernetes.io/is-default-class=true --overwrite"
fi

log "Waiting for all configured nodes to become Ready."
expected="$((1 + ${#WORKER_NAMES[@]}))"
deadline=$(( $(date +%s) + CLUSTER_READY_TIMEOUT_SECONDS ))

while (( $(date +%s) < deadline )); do
    total="$(run_remote "${CONTROL_IP}" \
        "kubectl get nodes --no-headers 2>/dev/null | wc -l" | tr -d ' ')"

    ready="$(run_remote "${CONTROL_IP}" \
        "kubectl get nodes --no-headers 2>/dev/null | awk '\$2 == \"Ready\" {count++} END {print count+0}'")"

    if [[ "${total}" -eq "${expected}" && "${ready}" -eq "${expected}" ]]; then
        break
    fi
    sleep 5
done

run_remote "${CONTROL_IP}" 'kubectl get nodes -o wide'
run_remote "${CONTROL_IP}" 'kubectl get pods -A'
run_remote "${CONTROL_IP}" 'kubectl get storageclass'

ready="$(run_remote "${CONTROL_IP}" \
    "kubectl get nodes --no-headers 2>/dev/null | awk '\$2 == \"Ready\" {count++} END {print count+0}'")"

[[ "${ready}" -eq "${expected}" ]] || \
    die "Not all nodes became Ready within ${CLUSTER_READY_TIMEOUT_SECONDS} seconds."

ok "Core cluster components installed and all nodes are Ready."
