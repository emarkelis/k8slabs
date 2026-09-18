
# v6_grok — Kubernetes Lab (kubeadm on Hyper-V)

A simple, beginner-friendly, fully **idempotent** kubeadm lab:  
**1 control plane + 2 workers** running on pre-created Ubuntu VMs in Hyper-V.

Designed so you can **reset and redeploy** the lab as many times as you want  
**without ever powering the VMs off or recreating them**.

---

## 1. What this solution does

- Turns three already-running Ubuntu VMs into a working Kubernetes cluster  
  (kubeadm + containerd + Calico + default StorageClass).
- Everything is driven from **one configuration file** (`lab.conf`).  
  Usernames, passwords, hostnames, IPs, paths and versions live only there.
- Fully **idempotent**: every script can be run again (on a fresh node or an  
  already-built cluster) and converges to the same clean state.
- The VMs themselves are **never touched**. Reset and redeploy only change  
  what runs *inside* the VMs.
- Day-to-day you only need **two commands**:
  - `./deploy-lab.sh`  → build or rebuild the cluster
  - `./reset-lab.sh`   → wipe Kubernetes state (VMs stay running)

---

## 2. Architecture

```
                    your admin machine
                 (bash + ssh + scp only)
                           │
          ┌────────────────┼────────────────┐
          │                │                │
      control         worker01         worker03
   192.168.178.51  192.168.178.52  192.168.178.53
  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
  │ containerd  │  │ containerd  │  │ containerd  │
  │ kubelet     │  │ kubelet     │  │ kubelet     │
  │ api-server  │  │             │  │             │
  │ etcd …      │  │             │  │             │
  └─────────────┘  └─────────────┘  └─────────────┘
          └────────── Calico CNI mesh ──────────┘
```

- All orchestration runs from **your admin machine**.
- Node-level scripts are copied to the VMs and executed remotely over SSH.
- You never need to log into a VM by hand for normal operation.
- `kubectl` is configured on the control node; you can also pull the  
  kubeconfig to your local machine with `fetch-kubeconfig.sh`.

### Script roles

| Type              | Scripts                                      | Where they run                  |
|-------------------|----------------------------------------------|---------------------------------|
| Node scripts      | `01_bootstrap-node.sh`, `02_reset-node.sh`   | Copied to & executed **on** each VM |
| Orchestration     | `03_init-control.sh`, `04_join-workers.sh`, `05_cluster-components.sh` | Run on **your machine** (SSH to VMs) |
| Entry points      | `deploy-lab.sh`, `reset-lab.sh`, `00_prepare-nodes.sh`, `fetch-kubeconfig.sh` | What you actually type |

---

## 3. Prerequisites

- Three Ubuntu VMs already created and **running** in Hyper-V  
  (Ubuntu 24.04 / 26.04 LTS or similar).
- Network connectivity between the VMs and your admin machine.
- The same Linux user exists on all three VMs and has sudo rights.
- On your admin machine: `bash`, `ssh`, `scp`.  
  Optionally `sshpass` (only needed for the one-time password-based setup).
- Internet access from the VMs (for apt packages and manifests).

---

## 4. File list

```
lab.conf                  # ← the ONLY file you should edit
lib/common.sh             # shared helpers (do not run directly)
00_prepare-nodes.sh       # one-time: SSH key + passwordless sudo
01_bootstrap-node.sh      # node script: install packages & configure system
02_reset-node.sh          # node script: wipe Kubernetes state
03_init-control.sh        # orchestration: kubeadm init
04_join-workers.sh        # orchestration: join workers
05_cluster-components.sh  # orchestration: Calico + local-path StorageClass
deploy-lab.sh             # ← main entry point (build / rebuild)
reset-lab.sh              # ← wipe cluster, keep VMs running
fetch-kubeconfig.sh       # convenience: pull kubeconfig to your machine
README.md                 # this file
```

---

## 5. Configuration

Open `lab.conf` and adjust the values to match your environment:

```bash
# ---- SSH / access -------------------------------------------------
SSH_USER="ubuntu"
SSH_KEY="$HOME/.ssh/k8s_lab_ed25519"
# Password is used ONLY by 00_prepare-nodes.sh. Blank it after first run.
SSH_PASSWORD=""

# ---- Paths --------------------------------------------------------
REMOTE_WORKDIR="/home/${SSH_USER}/k8s-lab"

# ---- Cluster nodes ------------------------------------------------
CONTROL_NAME="control"
CONTROL_IP="192.168.178.51"

WORKER_NAMES=("worker01" "worker03")
WORKER_IPS=("192.168.178.52" "192.168.178.53")

# ---- Kubernetes ---------------------------------------------------
K8S_VERSION="v1.31"          # pkgs.k8s.io minor line (v1.31, v1.32, …)
POD_CIDR="10.244.0.0/16"

# ---- Add-ons (pinned versions) ------------------------------------
CALICO_URL="https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/calico.yaml"
LOCAL_PATH_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml"
```

> **Security note**  
> `SSH_PASSWORD` is stored in plaintext. This is acceptable only for a  
> disposable lab on a private network. Blank the field once  
> `00_prepare-nodes.sh` has succeeded.

---

## 6. Execution instructions

### Step 1 — One-time node preparation

```bash
./00_prepare-nodes.sh
```

This installs your SSH key on all three VMs and enables passwordless sudo  
for `SSH_USER`.  

Skip this step entirely if the VMs already accept your SSH key and the user  
already has passwordless sudo.

### Step 2 — Deploy (or re-deploy) the cluster

```bash
./deploy-lab.sh
```

What happens (all steps are idempotent):

1. Checks SSH connectivity to every node.
2. Copies scripts + config to every node.
3. Bootstraps packages and system settings on all nodes.
4. Resets any previous Kubernetes state on all nodes.
5. Initializes the control plane with kubeadm.
6. Joins both workers.
7. Installs Calico and a default local-path StorageClass.
8. Waits for all three nodes to report `Ready` and prints the status.

You can run `./deploy-lab.sh` as many times as you like.  
It always produces a clean, consistent cluster.

### Step 3 — Use the cluster

```bash
./fetch-kubeconfig.sh
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes -o wide
kubectl get pods -A
```

Alternatively, just SSH to the control node — `kubectl` is already  
configured there for `SSH_USER`.

### Resetting the lab

```bash
./reset-lab.sh
```

This thoroughly wipes Kubernetes state on all three nodes  
(kubeadm reset, CNI interfaces, iptables rules, leftover directories).  
The VMs themselves stay powered on and ready for the next deploy.

### Redeploying

There is no separate “redeploy” command.  
Just run `./deploy-lab.sh` again — it always resets first.

---

## 7. Why this design is simple and reliable

- **Single source of truth** — everything comes from `lab.conf`.
- **Two commands** for daily use: `deploy-lab.sh` and `reset-lab.sh`.
- **Idempotent by design** — bootstrap, reset, init and join can all be  
  re-run safely without side-effects.
- **No VM lifecycle management** — Hyper-V VMs stay running at all times.
- **Pinned versions** — Calico and local-path provisioner are version-pinned  
  so a redeploy months later stays consistent.
- **Clear separation of concerns** — node scripts run on the VMs;  
  orchestration scripts run on your machine.

---

## 8. Troubleshooting

| Symptom                              | Likely cause / fix                                                                 |
|--------------------------------------|------------------------------------------------------------------------------------|
| SSH hangs or “Permission denied”     | Run `./00_prepare-nodes.sh` or verify key-based login manually                     |
| Node never becomes Ready             | Wait a bit longer for Calico; check `kubectl get pods -n calico-system`            |
| `kubeadm join` token / cert error    | Tokens expire after 24 h — just re-run `./deploy-lab.sh` (fresh token is created)  |
| Stale networking after a reset       | The reset script cleans CNI interfaces and iptables; re-run `./reset-lab.sh`       |
| You changed `lab.conf` after a deploy| Simply run `./deploy-lab.sh` again — it re-syncs config and scripts to every node  |

---

## 9. Quick reference

```bash
# One-time setup
./00_prepare-nodes.sh

# Build or rebuild the whole cluster
./deploy-lab.sh

# Wipe Kubernetes state (VMs stay up)
./reset-lab.sh

# Get a local kubeconfig
./fetch-kubeconfig.sh
export KUBECONFIG=$(pwd)/kubeconfig
```

