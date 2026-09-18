#!/usr/bin/env bash
# Installs node prerequisites. This script runs ON a lab VM.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# deploy-lab.sh uploads a password-free lab.conf into this directory.
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lab.conf"

log() { printf '\033[1;34m[BOOTSTRAP]\033[0m %s\n' "$*"; }
ok()  { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*" >&2; exit 1; }

sudo -n true >/dev/null 2>&1 || die "Passwordless sudo is required. Run 00_prepare-nodes.sh."

log "Checking operating system."
source /etc/os-release
if [[ -n "${REQUIRE_UBUNTU_VERSION:-}" ]]; then
    [[ "${ID}" == "ubuntu" && "${VERSION_ID}" == "${REQUIRE_UBUNTU_VERSION}" ]] ||         die "Expected Ubuntu ${REQUIRE_UBUNTU_VERSION}; found ${PRETTY_NAME}."
fi

log "Setting hostname to ${TARGET_HOSTNAME:-unknown}."
if [[ -n "${TARGET_HOSTNAME:-}" ]]; then
    current="$(hostnamectl --static 2>/dev/null || hostname)"
    if [[ "${current}" != "${TARGET_HOSTNAME}" ]]; then
        sudo hostnamectl set-hostname "${TARGET_HOSTNAME}"
    fi
fi

log "Disabling swap."
sudo swapoff -a || true
sudo sed -i -E '/^[[:space:]]*[^#].*[[:space:]]swap[[:space:]]/ s/^/# k8s-lab-disabled: /' /etc/fstab || true

log "Configuring kernel modules."
printf '%s\n' overlay br_netfilter | sudo tee /etc/modules-load.d/k8s-lab.conf >/dev/null
sudo modprobe overlay
sudo modprobe br_netfilter

log "Configuring kernel networking."
cat <<SYSCTL | sudo tee /etc/sysctl.d/99-k8s-lab.conf >/dev/null
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
SYSCTL
sudo sysctl --system >/dev/null

log "Installing prerequisite packages."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    ca-certificates curl gpg apt-transport-https \
    containerd conntrack socat ipset iptables iproute2

log "Configuring containerd for systemd cgroups."
sudo mkdir -p /etc/containerd/conf.d
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo rm -f /etc/containerd/conf.d/k8s-lab-v7.toml

CONTAINERD_MAJOR="$(containerd --version | sed -n 's/.*version \([0-9][0-9]*\)\..*/\1/p')"
case "${CONTAINERD_MAJOR}" in
    2)
        sudo tee /etc/containerd/conf.d/k8s-lab-v7.toml >/dev/null <<'TOML'
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
  SystemdCgroup = true
TOML
        ;;
    1)
        sudo tee /etc/containerd/conf.d/k8s-lab-v7.toml >/dev/null <<'TOML'
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
TOML
        ;;
    *)
        die "Unsupported containerd major version: ${CONTAINERD_MAJOR:-unknown}"
        ;;
esac

if grep -q '^imports[[:space:]]*=' /etc/containerd/config.toml; then
    sudo sed -i 's|^imports[[:space:]]*=.*|imports = ["/etc/containerd/conf.d/*.toml"]|' /etc/containerd/config.toml
else
    sudo sed -i '1i imports = ["/etc/containerd/conf.d/*.toml"]' /etc/containerd/config.toml
fi

# The lab needs the CRI plugin. Removing an explicit disabled_plugins setting
# is safer here than attempting to edit list punctuation.
sudo sed -i '/^[[:space:]]*disabled_plugins[[:space:]]*=/d' /etc/containerd/config.toml

sudo systemctl daemon-reload
sudo systemctl enable --now containerd
sudo systemctl restart containerd
sudo systemctl is-active --quiet containerd || die "containerd is not active."

log "Configuring Kubernetes package repository ${K8S_MINOR_VERSION}."
sudo rm -f /etc/apt/sources.list.d/kubernetes.list /etc/apt/sources.list.d/kubernetes.sources
sudo mkdir -p -m 755 /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR_VERSION}/deb/Release.key" | \
    sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

printf 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/%s/deb/ /\n' "${K8S_MINOR_VERSION}" | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

sudo apt-get update -qq
sudo apt-mark unhold kubelet kubeadm kubectl >/dev/null 2>&1 || true

if [[ -n "${K8S_PACKAGE_VERSION:-}" ]]; then
    log "Installing pinned Kubernetes package version ${K8S_PACKAGE_VERSION}."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        "kubelet=${K8S_PACKAGE_VERSION}" \
        "kubeadm=${K8S_PACKAGE_VERSION}" \
        "kubectl=${K8S_PACKAGE_VERSION}"
else
    log "Installing the newest patch available in ${K8S_MINOR_VERSION}."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq kubelet kubeadm kubectl
fi

sudo apt-mark hold kubelet kubeadm kubectl >/dev/null
sudo systemctl enable kubelet

log "Writing managed /etc/hosts entries."
sudo sed -i '/# BEGIN K8S-LAB-V7/,/# END K8S-LAB-V7/d' /etc/hosts
{
    echo '# BEGIN K8S-LAB-V7'
    echo "${CONTROL_IP} ${CONTROL_NAME}"
    for i in "${!WORKER_NAMES[@]}"; do
        echo "${WORKER_IPS[$i]} ${WORKER_NAMES[$i]}"
    done
    echo '# END K8S-LAB-V7'
} | sudo tee -a /etc/hosts >/dev/null

ok "Bootstrap complete on $(hostname)."
log "No reboot is performed by this lab."
