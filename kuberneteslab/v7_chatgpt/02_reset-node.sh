#!/usr/bin/env bash
# Removes Kubernetes lab state while leaving the Ubuntu VM operational.
set -euo pipefail

log() { printf '\033[1;33m[RESET]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

# A password-free lab.conf is uploaded beside this script.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lab.conf"

sudo -n true >/dev/null 2>&1 || die "Passwordless sudo is required."

log "Stopping kubelet."
sudo systemctl stop kubelet >/dev/null 2>&1 || true

if command -v kubeadm >/dev/null 2>&1; then
    log "Resetting kubeadm state."
    sudo kubeadm reset -f >/tmp/k8s-lab-v7-kubeadm-reset.log 2>&1 || {
        cat /tmp/k8s-lab-v7-kubeadm-reset.log >&2 || true
        warn "kubeadm reset reported an error; continuing with filesystem cleanup."
    }
else
    log "kubeadm is not installed yet; skipping kubeadm reset."
fi

log "Removing Kubernetes and CNI state."
sudo rm -rf \
    /etc/kubernetes \
    /etc/cni/net.d \
    /var/lib/cni \
    /var/lib/kubelet \
    /var/lib/etcd \
    /var/lib/calico \
    /var/run/calico \
    /var/log/calico \
    /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

rm -rf "${HOME}/.kube"

if [[ "${RESET_LOCAL_PATH_DATA:-true}" == "true" ]]; then
    if [[ -n "${LOCAL_PATH_DATA_PATH:-}" && "${LOCAL_PATH_DATA_PATH}" != "/" ]]; then
        log "Removing local-path lab data: ${LOCAL_PATH_DATA_PATH}"
        sudo rm -rf --one-file-system "${LOCAL_PATH_DATA_PATH}"
    fi
fi

log "Removing known leftover CNI interfaces without flushing the host firewall."
while read -r iface; do
    [[ -n "${iface}" ]] || continue
    sudo ip link delete "${iface}" >/dev/null 2>&1 || true
done < <(
    ip -o link show |
        awk -F': ' '{print $2}' |
        cut -d@ -f1 |
        grep -E '^(cni0|flannel\.1|vxlan\.calico|tunl0|cali[[:alnum:]_.-]+)$' || true
)

if systemctl list-unit-files containerd.service >/dev/null 2>&1; then
    log "Refreshing containerd."
    sudo systemctl restart containerd
    sudo systemctl is-active --quiet containerd || die "containerd failed to restart during reset."
fi

# The kubelet remains disabled/stopped until the next kubeadm init/join.
sudo systemctl disable kubelet >/dev/null 2>&1 || true

ok "Kubernetes lab state reset on $(hostname). The VM remains running."
