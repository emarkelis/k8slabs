# v4_mistral — Kubernetes Lab (kubeadm on Hyper-V)

A beginner-friendly, fully idempotent kubeadm lab: **1 control node + 2 workers**, running on pre-created Ubuntu 26.04 LTS VMs in Hyper-V. Designed for **reset and redeploy** without touching the VMs.

---

## 🎯 **Solution Overview**

This solution transforms three running Ubuntu VMs into a **production-like Kubernetes cluster** using:
- **kubeadm** for cluster initialization
- **containerd** as the container runtime
- **Calico** for networking (CNI)
- **local-path-provisioner** for dynamic local storage

**Key Features:**
✅ **Fully idempotent** – Every script can be rerun safely, ensuring consistent state.
✅ **Configuration-driven** – All variables (IPs, usernames, passwords, versions) are defined in **`lab.conf`**.
✅ **Non-destructive** – VMs remain powered on; only internal state (packages, Kubernetes, networking) is modified.
✅ **Beginner-friendly** – Minimal commands (`./deploy-lab.sh`, `./reset-lab.sh`), clear feedback, and troubleshooting guides.
✅ **Ubuntu 26.04 LTS** – Tested and optimized for the latest LTS release.

---

## 🏗️ **Architecture**

```
                     Your Admin Machine
                 (Runs orchestration scripts)
                              │
             ┌────────────────┼────────────────┐
             │                │                │
        control           worker01          worker03
     192.168.178.51    192.168.178.52    192.168.178.53
     ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
     │ containerd   │  │ containerd   │  │ containerd   │
     │ kubelet      │  │ kubelet      │  │ kubelet      │
     │ kube-apiserver│  │              │  │              │
     │ etcd         │  │              │  │              │
     └──────────────┘  └──────────────┘  └──────────────┘
             └────────── Calico CNI Mesh ──────────┘
```

- **All scripts run from your admin machine** (laptop, jump box, etc.) via SSH/SCP.
- **No manual VM logins** – Everything is automated remotely.
- **`kubectl` commands** are executed on the control node over SSH.

---

## 📁 **File Structure**

```
v4_mistral/
├── README.md                  # This file
├── lab.conf                   # Central configuration (edit this!)
├── lib/
│   └── common.sh              # Shared functions (sourced by scripts)
├── 00_prepare-nodes.sh        # One-time: Set up SSH keys + passwordless sudo
├── 01_bootstrap-node.sh       # Node script: Install packages & dependencies
├── 02_reset-node.sh           # Node script: Wipe Kubernetes state
├── 03_init-control.sh         # Orchestration: Initialize control plane
├── 04_join-workers.sh         # Orchestration: Join worker nodes
├── 05_cluster-components.sh   # Orchestration: Install Calico + StorageClass
├── deploy-lab.sh              # Entry point: Deploy/redeploy the cluster
├── reset-lab.sh               # Entry point: Reset the cluster (keep VMs running)
└── fetch-kubeconfig.sh        # Convenience: Pull kubeconfig to your admin machine
```

---

## 📝 **Configuration (`lab.conf`)**

Edit **`lab.conf`** to match your environment. Example:

```bash
# SSH Credentials
SSH_USER="ubuntu"
SSH_PASSWORD="your_password"  # Only for 00_prepare-nodes.sh; blank after use
SSH_KEY_PATH="$HOME/.ssh/id_rsa"  # Path to your private key

# Kubernetes Settings
K8S_VERSION="v1.31"            # Kubernetes minor version (e.g., v1.31)
POD_CIDR="192.168.0.0/16"       # Pod network CIDR (Calico default)
CALICO_VERSION="v3.28.0"       # Calico manifest version
LOCAL_PATH_VERSION="v0.0.26"   # Local-path-provisioner version

# Node IPs and Hostnames
CONTROL_NAME="control"
CONTROL_IP="192.168.178.51"
WORKER_NAMES=("worker01" "worker03")
WORKER_IPS=("192.168.178.52" "192.168.178.53")

# Repository (for script updates)
LAB_REPO_URL="https://github.com/emarkelis/k8slabs"
LAB_DIR="/home/${SSH_USER}/k8slabs/kuberneteslab/v4_mistral"
```

> ⚠️ **Security Note**: `SSH_PASSWORD` is in plaintext. **Blank it after running `00_prepare-nodes.sh`**.

---

## 🚀 **Prerequisites**

1. **VMs**: 3 Ubuntu 26.04 LTS VMs running in Hyper-V with:
   - Static IPs (or DHCP reservations).
   - Network connectivity between all nodes and your admin machine.
   - Same Linux user (`SSH_USER`) with sudo rights on all VMs.

2. **Admin Machine**: Must have:
   - `bash`, `ssh`, `scp`
   - `sshpass` (only if using password-based SSH in `00_prepare-nodes.sh`)

---

## 🛠️ **Setup Instructions**

### Step 1: Clone the Repository
```bash
git clone https://github.com/emarkelis/k8slabs
cd k8slabs/kuberneteslab/v4_mistral
```

### Step 2: Configure the Lab
Edit **`lab.conf`** with your settings (IPs, usernames, passwords, etc.).

### Step 3: One-Time Node Preparation (SSH Keys + Sudo)
Run this **once** to set up passwordless SSH and sudo:
```bash
./00_prepare-nodes.sh
```
- Installs your SSH public key on all nodes.
- Enables passwordless sudo for `SSH_USER`.
- **Blank `SSH_PASSWORD` in `lab.conf` after this succeeds.**

> Skip this step if your VMs already accept your SSH key and `SSH_USER` has passwordless sudo.

---

### Step 4: Deploy the Cluster
```bash
./deploy-lab.sh
```

This script:
1. Bootstraps all nodes (installs containerd, kubelet, kubeadm).
2. Resets any existing Kubernetes state (idempotent).
3. Initializes the control plane.
4. Joins worker nodes.
5. Installs Calico CNI and local-path-provisioner.
6. Waits for all nodes to report `Ready` and prints `kubectl get nodes -o wide`.

---

### Step 5: Access the Cluster

#### Option A: Use `kubectl` from Your Admin Machine
```bash
./fetch-kubeconfig.sh
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes -o wide
kubectl get pods -A
```

#### Option B: SSH to Control Node
```bash
ssh ${SSH_USER}@${CONTROL_IP}
kubectl get nodes
```

---

## 🔄 **Reset and Redeploy**

### Reset the Cluster (Keep VMs Running)
```bash
./reset-lab.sh
```
- Wipes Kubernetes state on all nodes.
- **VMs remain powered on** – Only internal state is cleared.

### Redeploy the Cluster
```bash
./deploy-lab.sh
```
- **No separate "redeploy" script needed** – `deploy-lab.sh` resets nodes first, then rebuilds the cluster.
- Run this anytime to start fresh.

---

## 🔍 **Troubleshooting**

| Issue | Solution |
|-------|----------|
| **`deploy-lab.sh` hangs at "Checking SSH to nodes"** | Confirm SSH access: `ssh ${SSH_USER}@${CONTROL_IP}`. Run `00_prepare-nodes.sh` if needed. |
| **Nodes stuck in `NotReady`** | Check Calico pods: `kubectl get pods -n calico-system`. Wait up to 3 minutes (slow networks). |
| **`kubeadm join` fails (token/cert error)** | Tokens expire after 24h. Rerun `./deploy-lab.sh` to generate a fresh token. |
| **Port 6443 blocked** | Ensure firewall allows traffic on port 6443 (control plane API). |
| **Containerd/cgroup errors** | Verify `systemd` cgroup driver in `/etc/containerd/config.toml`. |
| **Swap enabled** | Disable swap: `sudo swapoff -a` (handled automatically in `01_bootstrap-node.sh`). |

---

## 📌 **Script Details**

### Node Scripts (Run on Each VM)
| Script | Purpose |
|--------|---------|
| `01_bootstrap-node.sh` | Installs containerd, kubelet, kubeadm, and disables swap. |
| `02_reset-node.sh` | Resets Kubernetes state (`kubeadm reset`, cleans CNI/iptables). |

### Orchestration Scripts (Run from Admin Machine)
| Script | Purpose |
|--------|---------|
| `03_init-control.sh` | Initializes control plane with `kubeadm init`. |
| `04_join-workers.sh` | Joins worker nodes using `kubeadm join`. |
| `05_cluster-components.sh` | Installs Calico CNI and local-path-provisioner. |

### Entry Points (What You Run)
| Script | Purpose |
|--------|---------|
| `deploy-lab.sh` | **Main entry point**: Bootstraps, resets, deploys, and verifies the cluster. |
| `reset-lab.sh` | **Reset entry point**: Wipes Kubernetes state on all nodes. |
| `fetch-kubeconfig.sh` | Copies `kubeconfig` from control node to your admin machine. |

---

## 🎓 **Beginner Tips**

1. **Idempotence**: All scripts can be rerun safely. If something fails, just retry.
2. **Logs**: Check `/var/log/syslog` or `journalctl -u kubelet` on nodes for debugging.
3. **Networking**: Verify nodes can ping each other before deploying.
4. **Time Sync**: Ensure NTP is enabled on all VMs (`sudo timedatectl set-ntp true`).
5. **Resources**: Allocate at least **2 vCPUs + 4GB RAM** per VM for smooth operation.

---

## 📜 **License**
MIT License. Feel free to use, modify, and distribute.

---

## 🙌 **Acknowledgments**
Inspired by the original scripts in [emarkelis/k8slabs](https://github.com/emarkelis/k8slabs), with improvements for **simplicity**, **idempotence**, and **Ubuntu 26.04 LTS** support.
