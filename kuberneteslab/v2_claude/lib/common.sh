#!/bin/bash
# common.sh — shared helpers. Sourced by other scripts, never run directly.
# Assumes lab.conf has already been sourced by the caller.

log() {
  echo -e "\n[$(date +%H:%M:%S)] $*"
}

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5)
if [[ -n "${SSH_KEY:-}" ]]; then
  SSH_OPTS+=(-i "$SSH_KEY")
fi

ssh_run() {
  local host="$1"; shift
  ssh "${SSH_OPTS[@]}" "${SSH_USER}@${host}" "$@"
}

scp_to() {
  local src="$1" host="$2" dest="$3"
  scp "${SSH_OPTS[@]}" "$src" "${SSH_USER}@${host}:${dest}"
}

scp_from() {
  local host="$1" src="$2" dest="$3"
  scp "${SSH_OPTS[@]}" "${SSH_USER}@${host}:${src}" "$dest"
}

wait_for_ssh() {
  local host="$1"
  log "Checking SSH to ${host}..."
  local tries=0
  until ssh "${SSH_OPTS[@]}" "${SSH_USER}@${host}" true 2>/dev/null; do
    tries=$((tries + 1))
    if [[ "$tries" -ge 10 ]]; then
      echo "ERROR: could not SSH to ${SSH_USER}@${host} after 10 attempts." >&2
      echo "  - Is the VM running and reachable?" >&2
      echo "  - Has 00_prepare-nodes.sh been run yet (or is key-based login already set up)?" >&2
      exit 1
    fi
    sleep 3
  done
}

# Copies lab.conf + lib/common.sh + the per-node scripts onto a VM,
# so that node's own copy always matches your current lab.conf.
sync_node() {
  local host="$1"
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

  ssh_run "$host" "sudo mkdir -p ${REMOTE_WORKDIR}/lib && sudo chown -R ${SSH_USER}:${SSH_USER} ${REMOTE_WORKDIR}"
  scp_to "$dir/lab.conf" "$host" "${REMOTE_WORKDIR}/lab.conf"
  scp_to "$dir/lib/common.sh" "$host" "${REMOTE_WORKDIR}/lib/common.sh"
  scp_to "$dir/01_bootstrap-node.sh" "$host" "${REMOTE_WORKDIR}/01_bootstrap-node.sh"
  scp_to "$dir/02_reset-node.sh" "$host" "${REMOTE_WORKDIR}/02_reset-node.sh"
  ssh_run "$host" "chmod +x ${REMOTE_WORKDIR}/*.sh"
}

# Renders a marked block of /etc/hosts entries — deleting and
# re-adding the block makes this safe to run repeatedly.
render_hosts_block() {
  echo "# >>> k8s-lab >>>"
  echo "${CONTROL_IP} ${CONTROL_NAME}"
  for i in "${!WORKER_NAMES[@]}"; do
    echo "${WORKER_IPS[$i]} ${WORKER_NAMES[$i]}"
  done
  echo "# <<< k8s-lab <<<"
}

setup_hosts_remote() {
  local host="$1"
  ssh_run "$host" "sudo sed -i '/# >>> k8s-lab >>>/,/# <<< k8s-lab <<</d' /etc/hosts"
  render_hosts_block | ssh_run "$host" "sudo tee -a /etc/hosts >/dev/null"
}
