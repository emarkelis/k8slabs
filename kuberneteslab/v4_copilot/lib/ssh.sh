#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../config/credentials.conf"

run_ssh() {

    local host=$1

    shift

    if [[ "${AUTH_MODE}" == "password" ]]
    then

        sshpass \
          -p "${SSH_PASS}" \
          ssh \
          ${SSH_OPTIONS} \
          "${SSH_USER}@${host}" \
          "$@"

    else

        ssh \
          -i "${SSH_KEY}" \
          ${SSH_OPTIONS} \
          "${SSH_USER}@${host}" \
          "$@"

    fi
}

run_scp() {

    local source_file=$1
    local host=$2
    local target_file=$3

    if [[ "${AUTH_MODE}" == "password" ]]
    then

        sshpass \
          -p "${SSH_PASS}" \
          scp \
          ${SSH_OPTIONS} \
          "${source_file}" \
          "${SSH_USER}@${host}:${target_file}"

    else

        scp \
          -i "${SSH_KEY}" \
          ${SSH_OPTIONS} \
          "${source_file}" \
          "${SSH_USER}@${host}:${target_file}"

    fi
}
