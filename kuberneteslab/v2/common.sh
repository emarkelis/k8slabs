#!/bin/bash
# common.sh — shared helpers. Sourced by the other scripts, not run directly.

log() {
  echo -e "\n[$(date +%H:%M:%S)] $*"
}

ssh_run() {
  local host="$1"; shift
  ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes "${SSH_USER}@${host}" "$@"
}

scp_to() {
  local src="$1" host="$2" dest="$3"
  scp -o StrictHostKeyChecking=accept-new "$src" "${SSH_USER}@${host}:${dest}"
}

wait_for_ssh() {
  local host="$1"
  log "Waiting for SSH on ${host}..."
  until ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=3 \
    "${SSH_USER}@${host}" true 2>/dev/null; do
    sleep 3
  done
  log "${host} is reachable."
}

# Renders a marked block of /etc/hosts entries so re-running is idempotent
# (old block is deleted and replaced, never duplicated).
render_hosts_block() {
  echo "# >>> k8s-lab >>>"
  echo "${CONTROL_IP} ${CONTROL_HOST}"
  for i in "${!WORKER_HOSTS[@]}"; do
    echo "${WORKER_IPS[$i]} ${WORKER_HOSTS[$i]}"
  done
  echo "# <<< k8s-lab <<<"
}

setup_hosts_local() {
  log "Setting /etc/hosts locally"
  sudo sed -i '/# >>> k8s-lab >>>/,/# <<< k8s-lab <<</d' /etc/hosts
  render_hosts_block | sudo tee -a /etc/hosts >/dev/null
}

setup_hosts_remote() {
  local host="$1"
  log "Setting /etc/hosts on ${host}"
  ssh_run "$host" "sudo sed -i '/# >>> k8s-lab >>>/,/# <<< k8s-lab <<</d' /etc/hosts"
  render_hosts_block | ssh_run "$host" "sudo tee -a /etc/hosts >/dev/null"
}
