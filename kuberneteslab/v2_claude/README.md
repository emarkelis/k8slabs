# v2_claude — Kubernetes Lab (kubeadm on Hyper-V)

A small, beginner-friendly, fully idempotent kubeadm lab: 1 control node +
2 workers, running on pre-created Ubuntu VMs in Hyper-V. Designed so you
can reset and redeploy it as many times as you want without ever touching
the VMs themselves.

## 1. What this solution does

- Turns three already-running Ubuntu VMs into a working Kubernetes
  cluster (kubeadm, containerd, Calico networking, a default
  StorageClass).
- Everything is driven from **one config file** (`lab.conf`) — user,
  password, hostnames, IPs, paths, Kubernetes version, add-on versions.
  No values are hardcoded in the scripts.
- Everything is **idempotent**: every script can be run again, on a
  freshly-created node or a fully-built cluster, and it converges to
  the same clean state instead of erroring out or piling up leftovers.
- **The VMs are never touched.** "Reset" and "redeploy" only ever
  change what's running *inside* the three VMs (packages, Kubernetes
  state) — the VMs stay powered on throughout.
- There are exactly **two commands you need to remember day to day**:
  `./deploy-lab.sh` and `./reset-lab.sh`.

## 2. Architecture

```
                     your machine (admin)
                 (this repo, SSH + SCP only)
                              │
             ┌────────────────┼────────────────┐
             │                │                │
         control          worker01          worker03
      192.168.178.51   192.168.178.52   192.168.178.53
     ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
     │ containerd   │  │ containerd   │  │ containerd   │
     │ kubelet      │  │ kubelet      │  │ kubelet      │
     │ kube-apiserver│  │              │  │              │
     │ etcd, etc.   │  │              │  │              │
     └──────────────┘  └──────────────┘  └──────────────┘
             └────────── Calico CNI mesh ──────────┘
```

You never log into a VM by hand. Every script runs from **your own
machine** (a laptop, a jump box — anywhere with `bash`, `ssh`, and
`scp`) and reaches all three VMs symmetrically over SSH using the
credentials in `lab.conf`. `kubectl`/`kubeadm` commands that must run
"on the control node" are executed there remotely over SSH by the
orchestration scripts — you don't need `kubectl` installed locally
(though `fetch-kubeconfig.sh` lets you if you want it).

### Two kinds of scripts

| Type | Scripts | Where they run |
|---|---|---|
| **Node scripts** | `01_bootstrap-node.sh`, `02_reset-node.sh` | Copied to and executed *on* each VM |
| **Orchestration scripts** | `03_init-control.sh`, `04_join-workers.sh`, `05_cluster-components.sh` | Run *on your machine*, act on the VMs over SSH |
| **Entry points** | `deploy-lab.sh`, `reset-lab.sh`, `00_prepare-nodes.sh`, `fetch-kubeconfig.sh` | Run *on your machine* — these are what you actually type |

### Why it's idempotent

- `01_bootstrap-node.sh` only installs/configures things — every
  `apt install`, `sysctl`, `modprobe`, and file write is safe to repeat.
- `02_reset-node.sh` runs `kubeadm reset`, deletes `/etc/kubernetes`,
  `/var/lib/etcd`, `/var/lib/kubelet/*`, CNI config and leftover
  `cni0`/`flannel.1`/`vxlan.calico`/etc. interfaces, and flushes the
  iptables rules kube-proxy/Calico leave behind. This is what actually
  makes a second `kubeadm init` reliable — without it, stale networking
  state is the #1 cause of "it worked the first time but not the
  second."
- `deploy-lab.sh` **always** bootstraps and resets every node before
  rebuilding. That means "redeploy" has no separate meaning — it's the
  same command as "deploy." Run it as many times as you like.
- `/etc/hosts` entries are written inside a marked block that gets
  deleted and re-added each run, so re-running never duplicates lines.
- Add-on manifests (Calico, local-path-provisioner) are pinned to
  specific versions in `lab.conf`, so a redeploy in six months doesn't
  silently pull a different version than the one you tested.

## 3. Prerequisites

- Three Ubuntu VMs already created and **running** in Hyper-V, with
  network connectivity to each other and to your admin machine.
  (Tested against recent Ubuntu LTS point releases — if you're
  targeting a not-yet-released version like 26.04, the apt-based
  bootstrap here should work unchanged once that release is out; there
  is no OS-version-specific logic.)
- The same Linux user exists on all three VMs, with sudo rights.
- Your admin machine has `bash`, `ssh`, and `scp`.
- If you plan to use the password-based setup: `sshpass` on your admin
  machine (`sudo apt install sshpass` / `brew install sshpass`, etc.).

## 4. File list

```
lab.conf                  # <-- edit this
lib/common.sh              # shared helpers (not run directly)
00_prepare-nodes.sh        # one-time: SSH key + passwordless sudo setup
01_bootstrap-node.sh       # node script: install packages
02_reset-node.sh           # node script: wipe k8s state
03_init-control.sh         # orchestration: kubeadm init
04_join-workers.sh         # orchestration: join workers
05_cluster-components.sh   # orchestration: install/remove add-ons
deploy-lab.sh              # <-- entry point: build/rebuild the cluster
reset-lab.sh               # <-- entry point: wipe the cluster, keep VMs
fetch-kubeconfig.sh        # convenience: pull kubeconfig to your machine
README.md                  # this file
```

## 5. Configuration

Open `lab.conf` and fill in:

- `SSH_USER` — the Linux user on all three VMs.
- `SSH_PASSWORD` — that user's password, **only** needed for the
  one-time `00_prepare-nodes.sh` step below. Leave blank if you've
  already set up SSH keys yourself.
- `CONTROL_NAME` / `CONTROL_IP`, `WORKER_NAMES` / `WORKER_IPS` — match
  these to your Hyper-V VMs.
- `K8S_VERSION` — the Kubernetes minor line to install, e.g. `v1.31`.
- `POD_CIDR`, `CALICO_URL`, `LOCAL_PATH_URL` — sensible defaults are
  already filled in; change only if you know you need to.

## 6. Running it

### Step 1 — one-time node preparation

```bash
./00_prepare-nodes.sh
```

Uses `SSH_PASSWORD` to install your SSH key on all three VMs and turn
on passwordless sudo for `SSH_USER`. Skip this step entirely if the
three VMs already accept your SSH key and `SSH_USER` already has
passwordless sudo.

> **Security note:** `SSH_PASSWORD` sits in plaintext in `lab.conf`.
> This is fine for a disposable lab on a private network — never reuse
> a real password here. Blank the field out once step 1 has succeeded.

### Step 2 — deploy the cluster

```bash
./deploy-lab.sh
```

This bootstraps packages, resets any old state, initializes the
control plane, joins both workers, and installs Calico + a default
StorageClass — then waits for all three nodes to report `Ready` and
prints `kubectl get nodes -o wide`.

### Step 3 — use the cluster

```bash
./fetch-kubeconfig.sh
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get pods -A
```

...or just SSH to control and run `kubectl` there directly — it's
already configured for `SSH_USER`.

### Resetting

```bash
./reset-lab.sh
```

Wipes Kubernetes state on all three VMs. The VMs themselves are left
running — nothing about them is torn down or recreated.

### Redeploying

There's no separate "redeploy" script — just run `./deploy-lab.sh`
again. It resets first, every time, so it always produces a clean
cluster regardless of what state the nodes were in before.

## 7. Troubleshooting

- **`deploy-lab.sh` hangs at "checking SSH to every node"** — a VM
  isn't reachable, or `00_prepare-nodes.sh` hasn't run yet and no
  key-based login exists. Confirm you can manually
  `ssh -i <SSH_KEY> <SSH_USER>@<IP>` to each node.
- **A node never goes `Ready`** — check Calico's pods:
  `ssh <control> kubectl get pods -n calico-system` (or `-n
  kube-system` on older Calico manifests). Often it just needs more
  time on a slow lab network; `deploy-lab.sh` already waits up to 3
  minutes before giving up and just showing you the current state.
- **`kubeadm join` fails with a token/cert error** — tokens expire
  after 24h. Just re-run `./deploy-lab.sh`; it always fetches a fresh
  token via `04_join-workers.sh`.
- **You changed `lab.conf` after a previous deploy** — just run
  `./deploy-lab.sh` again; it re-syncs the config and scripts to every
  node before doing anything else.
