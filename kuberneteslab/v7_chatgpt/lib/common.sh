#!/usr/bin/env bash
# Shared functions for Kubernetes Lab v7.
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${LIB_DIR}/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/lab.conf"

if [[ ! -r "${CONFIG_FILE}" ]]; then
    echo "ERROR: Configuration file not found: ${CONFIG_FILE}" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${CONFIG_FILE}"

: "${LAB_REPO_URL:?LAB_REPO_URL is required}"
: "${SSH_USER:?SSH_USER is required}"
: "${SSH_KEY_PATH:?SSH_KEY_PATH is required}"
: "${REMOTE_WORKDIR:?REMOTE_WORKDIR is required}"
: "${CONTROL_NAME:?CONTROL_NAME is required}"
: "${CONTROL_IP:?CONTROL_IP is required}"
: "${POD_CIDR:?POD_CIDR is required}"
: "${SERVICE_CIDR:?SERVICE_CIDR is required}"
: "${K8S_MINOR_VERSION:?K8S_MINOR_VERSION is required}"
: "${CALICO_VERSION:?CALICO_VERSION is required}"
: "${CALICO_URL:?CALICO_URL is required}"
: "${LOCAL_PATH_VERSION:?LOCAL_PATH_VERSION is required}"
: "${LOCAL_PATH_URL:?LOCAL_PATH_URL is required}"
: "${LOCAL_PATH_DATA_PATH:?LOCAL_PATH_DATA_PATH is required}"

ALL_NAMES=("${CONTROL_NAME}" "${WORKER_NAMES[@]}")
ALL_IPS=("${CONTROL_IP}" "${WORKER_IPS[@]}")

ssh_opts=(
    -i "${SSH_KEY_PATH}"
    -o "StrictHostKeyChecking=${SSH_STRICT_HOST_KEY_CHECKING:-accept-new}"
    -o "ConnectTimeout=${SSH_CONNECT_TIMEOUT:-10}"
    -o ServerAliveInterval=15
    -o ServerAliveCountMax=3
    -o LogLevel=ERROR
)

scp_opts=(
    -i "${SSH_KEY_PATH}"
    -o "StrictHostKeyChecking=${SSH_STRICT_HOST_KEY_CHECKING:-accept-new}"
    -o "ConnectTimeout=${SSH_CONNECT_TIMEOUT:-10}"
    -o LogLevel=ERROR
)

log()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

require_command() {
    local cmd="$1"
    command -v "${cmd}" >/dev/null 2>&1 || die "Required command not found: ${cmd}"
}

is_valid_ipv4() {
    local ip="$1"
    local IFS=.
    local -a octets=()
    read -r -a octets <<< "${ip}"
    [[ "${#octets[@]}" -eq 4 ]] || return 1

    local octet
    for octet in "${octets[@]}"; do
        [[ "${octet}" =~ ^[0-9]+$ ]] || return 1
        (( octet >= 0 && octet <= 255 )) || return 1
    done
}

validate_simple_name() {
    [[ "$1" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]
}

validate_config() {
    local i name ip count x

    [[ "${#WORKER_NAMES[@]}" -eq "${#WORKER_IPS[@]}" ]] ||         die "WORKER_NAMES and WORKER_IPS must have the same number of entries."
    (( ${#WORKER_NAMES[@]} >= 1 )) || die "At least one worker is required."

    [[ "${SSH_USER}" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] ||         die "SSH_USER is not a simple Linux username: ${SSH_USER}"

    validate_simple_name "${CONTROL_NAME}" || die "Invalid CONTROL_NAME: ${CONTROL_NAME}"
    is_valid_ipv4 "${CONTROL_IP}" || die "Invalid CONTROL_IP: ${CONTROL_IP}"

    [[ "${POD_CIDR}" == */* ]] || die "POD_CIDR must be CIDR notation."
    [[ "${SERVICE_CIDR}" == */* ]] || die "SERVICE_CIDR must be CIDR notation."
    [[ "${K8S_MINOR_VERSION}" =~ ^v[0-9]+\.[0-9]+$ ]] ||         die "K8S_MINOR_VERSION must look like v1.37."

    [[ "${LOCAL_PATH_DATA_PATH}" == /* && "${LOCAL_PATH_DATA_PATH}" != "/" ]] ||         die "LOCAL_PATH_DATA_PATH must be an absolute path other than /."

    for i in "${!WORKER_NAMES[@]}"; do
        validate_simple_name "${WORKER_NAMES[$i]}" ||             die "Invalid worker name: ${WORKER_NAMES[$i]}"
        is_valid_ipv4 "${WORKER_IPS[$i]}" ||             die "Invalid worker IP: ${WORKER_IPS[$i]}"
    done

    for name in "${ALL_NAMES[@]}"; do
        count=0
        for x in "${ALL_NAMES[@]}"; do
            [[ "${x}" == "${name}" ]] && ((count+=1))
        done
        (( count == 1 )) || die "Duplicate node name in configuration: ${name}"
    done

    for ip in "${ALL_IPS[@]}"; do
        count=0
        for x in "${ALL_IPS[@]}"; do
            [[ "${x}" == "${ip}" ]] && ((count+=1))
        done
        (( count == 1 )) || die "Duplicate node IP in configuration: ${ip}"
    done
}

check_ssh() {
    local ip="$1"
    ssh "${ssh_opts[@]}" "${SSH_USER}@${ip}" true >/dev/null 2>&1 ||         die "Cannot SSH to ${SSH_USER}@${ip}. Run 00_prepare-nodes.sh or check connectivity."
}

check_passwordless_sudo() {
    local ip="$1"
    ssh "${ssh_opts[@]}" "${SSH_USER}@${ip}" 'sudo -n true' >/dev/null 2>&1 ||         die "${SSH_USER}@${ip} does not have passwordless sudo. Run 00_prepare-nodes.sh."
}

run_remote() {
    local ip="$1"
    shift
    ssh "${ssh_opts[@]}" "${SSH_USER}@${ip}" "$@"
}

scp_to() {
    local ip="$1"
    local src="$2"
    local dst="$3"
    scp "${scp_opts[@]}" "${src}" "${SSH_USER}@${ip}:${dst}"
}

start_log() {
    local name="$1"
    local dir="${LOCAL_LOG_DIR:-${ROOT_DIR}/logs}"
    mkdir -p "${dir}"
    local file="${dir}/${name}-$(date +%Y%m%d-%H%M%S).log"
    exec > >(tee -a "${file}") 2>&1
    log "Log file: ${file}"
}

build_remote_config() {
    # Deliberately excludes SSH_PASSWORD and other local-only settings.
    local out="$1"
    {
        printf '# Generated by Kubernetes Lab v7. DO NOT EDIT.\n'
        printf 'CONTROL_NAME=%q\n' "${CONTROL_NAME}"
        printf 'CONTROL_IP=%q\n' "${CONTROL_IP}"
        printf 'POD_CIDR=%q\n' "${POD_CIDR}"
        printf 'SERVICE_CIDR=%q\n' "${SERVICE_CIDR}"
        printf 'CLUSTER_DNS_DOMAIN=%q\n' "${CLUSTER_DNS_DOMAIN}"
        printf 'REQUIRE_UBUNTU_VERSION=%q\n' "${REQUIRE_UBUNTU_VERSION}"
        printf 'K8S_MINOR_VERSION=%q\n' "${K8S_MINOR_VERSION}"
        printf 'K8S_PACKAGE_VERSION=%q\n' "${K8S_PACKAGE_VERSION}"
        printf 'REMOTE_WORKDIR=%q\n' "${REMOTE_WORKDIR}"
        printf 'SSH_USER=%q\n' "${SSH_USER}"
        printf 'CALICO_VERSION=%q\n' "${CALICO_VERSION}"
        printf 'CALICO_URL=%q\n' "${CALICO_URL}"
        printf 'LOCAL_PATH_VERSION=%q\n' "${LOCAL_PATH_VERSION}"
        printf 'LOCAL_PATH_URL=%q\n' "${LOCAL_PATH_URL}"
        printf 'LOCAL_PATH_DATA_PATH=%q\n' "${LOCAL_PATH_DATA_PATH}"
        printf 'RESET_LOCAL_PATH_DATA=%q\n' "${RESET_LOCAL_PATH_DATA}"
        printf 'DEFAULT_STORAGE_CLASS=%q\n' "${DEFAULT_STORAGE_CLASS}"
        printf 'WORKER_NAMES=('
        printf ' %q' "${WORKER_NAMES[@]}"
        printf ' )\n'
        printf 'WORKER_IPS=('
        printf ' %q' "${WORKER_IPS[@]}"
        printf ' )\n'
    } > "${out}"
}
