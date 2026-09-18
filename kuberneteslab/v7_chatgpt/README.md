# Kubernetes Lab v7 — ChatGPT

A small, repeatable Kubernetes learning lab built for **three pre-created Hyper-V Ubuntu VMs**:

| Role | Name | IP |
|---|---|---|
| Control plane | `control` | `192.168.178.51` |
| Worker | `worker01` | `192.168.178.52` |
| Worker | `worker03` | `192.168.178.53` |

The design treats the VMs as **persistent infrastructure**. The automation never powers them off, deletes them, recreates them, or intentionally reboots them.

> **Ubuntu version naming:** this solution treats “Ubuntu 26.0 LTS” as **Ubuntu 26.04 LTS**.

## 1. What v7 is designed to do

The two main design goals are:

1. **Simplicity** — a beginner should normally edit one file and use a small number of commands.
2. **Idempotence** — the same command can be run again without requiring manual cleanup.

The main workflow is:

```text
Admin machine
     |
     | SSH / SCP
     v
+-------------+       +-------------+       +-------------+
|   control   |       |  worker01   |       |  worker03   |
| 192.168.178.51       | 192.168.178.52      | 192.168.178.53
+-------------+       +-------------+       +-------------+
        \                    |                     /
         \________________ Kubernetes ___________/
                         kubeadm
                       containerd
                         Calico
                    local-path storage
```

### What remains running

The Ubuntu VMs remain running throughout the lab lifecycle.

### What is reset

`reset-lab.sh` removes the Kubernetes cluster state, kubelet state, CNI state and (by default) local-path PersistentVolume data.

It does **not**:

- power off a VM;
- reboot a VM;
- recreate a VM;
- remove Ubuntu;
- remove the SSH account;
- remove the SSH key;
- globally flush the host firewall;
- remove unrelated host configuration.

This makes the lab suitable for repeated exercises on long-lived Hyper-V guests.

---

# 2. Architecture

## 2.1 Control plane

There is exactly one control-plane node:

```text
control
192.168.178.51
TCP 6443  Kubernetes API
```

The kubeadm control-plane endpoint is:

```text
192.168.178.51:6443
```

There is deliberately no external load balancer because this is a three-VM learning lab.

## 2.2 Workers

```text
worker01  192.168.178.52
worker03  192.168.178.53
```

Each worker runs:

- kubelet;
- containerd;
- Calico node networking;
- local-path storage support.

## 2.3 Container runtime

The lab uses **containerd**, not Docker.

The bootstrap script detects whether the installed containerd is major version 1 or 2 and writes the appropriate `SystemdCgroup = true` setting.

This is important because Kubernetes documentation recommends the systemd cgroup driver for hosts using systemd and cgroup v2, and the containerd configuration path differs between containerd 1.x and 2.x.

## 2.4 Kubernetes installation

Kubernetes packages are installed from the modern `pkgs.k8s.io` repository.

The minor release is controlled by:

```bash
K8S_MINOR_VERSION="v1.37"
```

An optional exact Debian package version is available:

```bash
K8S_PACKAGE_VERSION=""
```

Leaving it empty means:

> install the newest patch release currently available in the configured Kubernetes minor repository.

For a completely frozen lab, set an exact package version after verifying which version is available on the VMs.

## 2.5 Pod and Service networks

The example configuration is:

```text
Pod network:     10.244.0.0/16
Service network: 10.96.0.0/12
```

These are intentionally different from the VM LAN:

```text
VM LAN: 192.168.178.0/24
```

Do not create an overlap between the Hyper-V network and the Kubernetes Pod/Service networks.

## 2.6 CNI: Calico

Calico provides the Kubernetes pod network.

The lab pins Calico to:

```text
v3.32.2
```

The pinned manifest is downloaded from the Calico project during deployment.

The manifest's `CALICO_IPV4POOL_CIDR` setting is enabled and changed to the configured `POD_CIDR` before applying it.

This matters because the Calico manifest documents that this value is the default IPv4 pool created on first startup and should fall inside Kubernetes' cluster CIDR.

The lab deliberately stays with Calico's simple IP-in-IP mode from the upstream manifest rather than adding another networking layer.

## 2.7 Storage: local-path

The lab installs Rancher's local-path provisioner:

```text
v0.0.37
```

It creates the `local-path` StorageClass.

By default, v7 marks `local-path` as the default StorageClass.

The storage path on each VM is:

```text
/opt/local-path-provisioner
```

This is **local** storage, not replicated storage. A PersistentVolume exists on the node where it is provisioned.

Because this is a lab, `RESET_LOCAL_PATH_DATA="true"` by default. A full lab reset therefore removes those local files as well.

---

# 3. Design principles

## 3.1 One central configuration file

Normally edit only:

```text
lab.conf
```

It contains:

- repository information;
- local paths;
- SSH username;
- SSH key path;
- temporary password;
- VM names;
- VM IP addresses;
- Kubernetes version;
- Pod and Service CIDRs;
- Calico version and URL;
- local-path version and URL;
- reset behaviour;
- worker join-token TTL;
- readiness timeout.

There are no node-specific IP addresses hidden inside the orchestration scripts.

## 3.2 Credentials are not copied to the nodes

The full local `lab.conf` is **never** uploaded.

`deploy-lab.sh` generates a temporary, password-free remote configuration containing only values required by the node-side scripts.

That means:

```text
SSH_PASSWORD
```

does not get copied to the VMs.

## 3.3 VMs are persistent

The scripts contain no Hyper-V commands.

There is no:

```text
Stop-VM
Start-VM
Restart-VM
Remove-VM
```

and there is no Linux reboot.

## 3.4 Reset is intentionally narrower than many “cluster reset” scripts

A dangerous pattern in some lab reset scripts is:

```text
iptables -F
iptables -t nat -F
```

That is deliberately **not** used here.

The host firewall belongs to the operating system and may be needed for the VM's other services.

v7 removes known Kubernetes/CNI state and known CNI interfaces but does not globally erase the host firewall.

---

# 4. Files

```text
v7_chatgpt/
├── README.md
├── lab.conf
├── .gitignore
├── check-lab.sh
├── 00_prepare-nodes.sh
├── 01_bootstrap-node.sh
├── 02_reset-node.sh
├── 03_init-control.sh
├── 04_join-workers.sh
├── 05_cluster-components.sh
├── deploy-lab.sh
├── reset-lab.sh
├── status-lab.sh
├── fetch-kubeconfig.sh
└── lib/
    └── common.sh
```

### `lab.conf`

The central configuration.

### `check-lab.sh`

Performs local configuration validation and `bash -n` checks. It does not contact the VMs.

### `00_prepare-nodes.sh`

One-time access preparation.

It:

- creates an SSH key if required;
- installs the public key on each VM when password authentication is available;
- configures passwordless sudo;
- verifies the result.

It is safe to run again.

### `01_bootstrap-node.sh`

Runs on a VM.

It:

- verifies Ubuntu 26.04;
- sets the hostname;
- disables swap;
- loads kernel modules;
- applies required sysctls;
- installs containerd and networking utilities;
- configures containerd for systemd cgroups;
- installs kubelet/kubeadm/kubectl;
- pins the installed packages with `apt-mark hold`;
- manages `/etc/hosts`;
- enables kubelet.

It does not reboot.

### `02_reset-node.sh`

Runs on a VM.

It removes:

- kubeadm state;
- `/etc/kubernetes`;
- CNI configuration;
- Kubernetes runtime state;
- Calico host state;
- the user's `.kube` directory;
- optional local-path data.

It also removes known Kubernetes CNI interfaces.

It does not flush all iptables rules.

### `03_init-control.sh`

Creates the kubeadm `v1beta4` configuration and initialises the control plane.

The kubeadm configuration includes:

- the control-plane advertise address;
- node name;
- containerd CRI socket;
- Kubernetes version;
- Pod CIDR;
- Service CIDR;
- cluster DNS domain;
- API certificate SANs.

### `04_join-workers.sh`

Generates a new, short-lived kubeadm join token and joins all workers.

The worker node name is explicitly passed to kubeadm.

### `05_cluster-components.sh`

Installs:

- Calico;
- local-path storage;
- optional default StorageClass setting.

It then waits until every configured node is `Ready`.

### `deploy-lab.sh`

The normal entry point.

It performs:

```text
validate configuration
        |
check SSH
        |
check passwordless sudo
        |
sync node scripts/config
        |
reset all Kubernetes state
        |
bootstrap all nodes
        |
kubeadm init on control
        |
kubeadm join on workers
        |
install Calico
        |
install local-path
        |
wait for all nodes Ready
```

Running it again repeats the full process.

### `reset-lab.sh`

Fast reset without rebuilding.

Use it when you want the VMs clean but you do not want to run a new deployment immediately.

### `status-lab.sh`

Shows:

- node reachability;
- hostname;
- Ubuntu version;
- containerd status;
- kubelet status;
- passwordless sudo status;
- Kubernetes nodes;
- Kubernetes pods;
- StorageClasses.

### `fetch-kubeconfig.sh`

Copies the control-plane admin kubeconfig to:

```text
.secrets/kubeconfig
```

It is ignored by Git.

---

# 5. Prerequisites on the administration machine

The easiest administration environment is:

- Linux;
- WSL2;
- another Ubuntu machine.

You need:

```bash
bash
ssh
scp
ssh-keygen
```

For the first-time password-based preparation you also need:

```bash
sshpass
ssh-copy-id
```

On Ubuntu/WSL:

```bash
sudo apt-get update
sudo apt-get install -y openssh-client sshpass
```

You do **not** need PowerShell or Hyper-V PowerShell cmdlets for the v7 scripts.

Hyper-V is only used to create/run the VMs.

---

# 6. Initial VM assumptions

The three VMs should already exist and be running.

Each VM should have:

- Ubuntu 26.04 LTS;
- a working network connection;
- an SSH server;
- the configured Linux user;
- permission to use `sudo`.

The sample configuration assumes:

```text
ubuntu@192.168.178.51
ubuntu@192.168.178.52
ubuntu@192.168.178.53
```

---

# 7. First-time implementation

## Step 1 — Put the repository on the administration machine

For example:

```bash
mkdir -p "$HOME/k8slabs"
cd "$HOME/k8slabs"

git clone https://github.com/emarkelis/k8slabs.git
cd k8slabs/kuberneteslab/v7_chatgpt
```

If you already have the repository locally, simply go to the v7 directory.

## Step 2 — Edit `lab.conf`

At minimum verify:

```bash
SSH_USER="ubuntu"
SSH_KEY_PATH="$HOME/.ssh/k8s_lab_v7_ed25519"

CONTROL_NAME="control"
CONTROL_IP="192.168.178.51"

WORKER_NAMES=("worker01" "worker03")
WORKER_IPS=("192.168.178.52" "192.168.178.53")
```

and:

```bash
REMOTE_WORKDIR="/home/${SSH_USER}/k8s-lab-v7"
```

For a different lab, this is where you change names, IPs and paths.

## Step 3 — Make the scripts executable

```bash
chmod +x ./*.sh
./check-lab.sh
```

## Step 4 — Prepare node access

If the Ubuntu account already has SSH key access and passwordless sudo, you can skip this step.

Otherwise temporarily put the user's password into:

```bash
SSH_PASSWORD="your-temporary-lab-password"
```

Then run:

```bash
./00_prepare-nodes.sh
```

The script creates:

```text
~/.ssh/k8s_lab_v7_ed25519
~/.ssh/k8s_lab_v7_ed25519.pub
```

and configures passwordless sudo.

After successful preparation, remove the password again:

```bash
SSH_PASSWORD=""
```

Do not commit a real password to GitHub.

## Step 5 — Deploy

Run:

```bash
./deploy-lab.sh
```

The script does the complete build.

When it finishes:

```text
control   Ready
worker01  Ready
worker03  Ready
```

should be visible.

---

# 8. Normal daily commands

## Check the lab

```bash
./status-lab.sh
```

## Rebuild the entire Kubernetes cluster

```bash
./deploy-lab.sh
```

This is the main repeatable command.

It intentionally resets the existing Kubernetes cluster first.

## Reset only

```bash
./reset-lab.sh
```

Then later:

```bash
./deploy-lab.sh
```

## Get the kubeconfig

```bash
./fetch-kubeconfig.sh
```

Then:

```bash
export KUBECONFIG="$PWD/.secrets/kubeconfig"
kubectl get nodes -o wide
```

You should see three nodes.

---

# 9. Expected end state

After a successful deployment:

```bash
kubectl get nodes -o wide
```

should show three nodes:

```text
control
worker01
worker03
```

and:

```bash
kubectl get pods -A
```

should show the expected system components, including Calico.

Storage:

```bash
kubectl get storageclass
```

should show:

```text
local-path
```

as the default StorageClass when:

```bash
DEFAULT_STORAGE_CLASS="true"
```

---

# 10. How repeatability works

A typical lab cycle can be:

```text
Start with three running VMs
             |
             v
       ./deploy-lab.sh
             |
             v
     Perform exercise
             |
             v
       ./reset-lab.sh
             |
             v
     Exercise complete
             |
             +------> ./deploy-lab.sh
                        |
                        v
                    New cluster
```

The VMs themselves never leave the cycle.

This is particularly useful for training where the same exercise must be repeated many times.

---

# 11. Idempotence details

## Configuration

The configuration is validated every time an entry point starts.

The scripts reject:

- invalid IPv4 addresses;
- duplicate node names;
- duplicate node addresses;
- malformed Kubernetes minor versions;
- mismatched worker name/IP arrays;
- unsafe local storage paths.

## Hostname

The hostname is set only when it differs from the requested name.

## `/etc/hosts`

v7 owns only this block:

```text
# BEGIN K8S-LAB-V7
...
# END K8S-LAB-V7
```

The block is replaced on each bootstrap.

Other `/etc/hosts` entries are left alone.

## Swap

Uncommented swap lines in `/etc/fstab` are commented only once.

## containerd

The bootstrap recreates the generated containerd base configuration and manages its own drop-in:

```text
/etc/containerd/conf.d/k8s-lab-v7.toml
```

The appropriate configuration path is selected for containerd 1.x or 2.x.

## Kubernetes packages

Packages are unheld before the install and held afterwards.

## Kubernetes cluster

`deploy-lab.sh` resets the previous cluster before initialising a new one.

## Calico

The manifest is pinned and downloaded again on each deployment.

## local-path

The stable pinned manifest is applied using `kubectl apply`, so applying the same definition again is safe.

---

# 12. Reset safety

There is an important distinction between:

```text
VM reset
```

and:

```text
Kubernetes reset
```

v7 performs the second one.

It does not use Hyper-V automation.

It does not use:

```bash
shutdown
reboot
```

and it intentionally does not use a global firewall flush.

The reset does remove Kubernetes-specific state, so it is destructive to the current cluster.

It also removes local-path storage data when:

```bash
RESET_LOCAL_PATH_DATA="true"
```

That means local PersistentVolume data is treated as disposable lab state.

Set:

```bash
RESET_LOCAL_PATH_DATA="false"
```

when you want the local-path directory to survive a Kubernetes reset.

Note that local-path storage is node-local. It is not a substitute for a replicated storage system.

---

# 13. Troubleshooting

## 13.1 SSH fails

Test the control node directly:

```bash
ssh -i "$HOME/.ssh/k8s_lab_v7_ed25519" ubuntu@192.168.178.51
```

Then:

```bash
ssh -i "$HOME/.ssh/k8s_lab_v7_ed25519" ubuntu@192.168.178.51 "sudo -n true"
```

The second command must succeed without prompting for a password.

## 13.2 First-time access does not work

Put the VM password temporarily into:

```bash
SSH_PASSWORD="..."
```

and run:

```bash
./00_prepare-nodes.sh
```

The preparation script requires `sshpass` and `ssh-copy-id` if key access is not already available.

## 13.3 Host-key warning after rebuilding a VM

Because the lab intentionally uses persistent VMs, an unexpected host-key change is treated as a security event.

If you deliberately recreated a VM, remove its old key:

```bash
ssh-keygen -R 192.168.178.51
ssh-keygen -R 192.168.178.52
ssh-keygen -R 192.168.178.53
```

Then run preparation again.

## 13.4 Check containerd

On a VM:

```bash
systemctl status containerd --no-pager
```

Then:

```bash
containerd --version
```

## 13.5 Check kubelet

```bash
systemctl status kubelet --no-pager
```

Logs:

```bash
sudo journalctl -u kubelet -n 100 --no-pager
```

## 13.6 kubeadm init fails

On the control node:

```bash
sudo kubeadm init phase preflight
```

and inspect:

```bash
sudo journalctl -u kubelet -n 100 --no-pager
```

Also verify:

```bash
free -h
swapon --show
systemctl is-active containerd
```

`swapon --show` should normally be empty.

## 13.7 Worker will not join

On the worker:

```bash
sudo journalctl -u kubelet -n 100 --no-pager
```

On the control node:

```bash
kubectl get nodes
```

A new deployment creates a new join token, so do not reuse an old join command from a previous reset.

## 13.8 Calico pods are not Ready

Run:

```bash
kubectl get pods -n kube-system -o wide
```

Then:

```bash
kubectl describe pod -n kube-system <calico-pod-name>
```

and:

```bash
kubectl logs -n kube-system <calico-pod-name> -c calico-node
```

The first things to check are:

```text
Pod CIDR
VM network
containerd
kernel modules
IP forwarding
```

## 13.9 All nodes exist but remain NotReady

Run:

```bash
kubectl describe node control
kubectl describe node worker01
kubectl describe node worker03
```

Then:

```bash
kubectl get pods -n kube-system -o wide
```

A kubeadm cluster normally needs a functioning CNI before nodes become fully usable.

---

# 14. Manual validation commands

These are useful when learning what the scripts are actually doing.

On each VM:

```bash
hostname
cat /etc/os-release
systemctl is-active containerd
systemctl is-enabled kubelet
sysctl net.ipv4.ip_forward
lsmod | grep br_netfilter
```

On the control node:

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
kubectl get storageclass
```

Inspect the Kubernetes version:

```bash
kubectl version
```

Inspect kubeadm:

```bash
kubeadm version
```

---

# 15. Changing the Kubernetes version

Edit:

```bash
K8S_MINOR_VERSION="v1.37"
```

For example, when deliberately moving to a newer supported minor:

```bash
K8S_MINOR_VERSION="v1.38"
```

Then run:

```bash
./deploy-lab.sh
```

Because deployment includes a reset, the lab is rebuilt from the requested package repository.

Do not change a running cluster's Kubernetes minor version by simply rerunning bootstrap. v7's normal lab workflow is intentionally:

```text
reset
bootstrap
init
join
CNI
storage
```

This is a **rebuild**, not an in-place production upgrade procedure.

---

# 16. Changing the topology

The v7 scripts are written for one control plane plus one or more workers.

To add a worker, extend both arrays together.

Example:

```bash
WORKER_NAMES=("worker01" "worker03" "worker04")
WORKER_IPS=("192.168.178.52" "192.168.178.53" "192.168.178.54")
```

The arrays must have exactly the same number of elements.

The rest of the orchestration automatically uses the expanded list.

For a beginner lab, keeping one control and two workers is recommended because it makes the architecture easy to understand.

---

# 17. Why this solution is intentionally small

Several earlier lab designs add:

- Helm;
- metrics-server;
- Prometheus;
- Grafana;
- OpenTelemetry;
- additional storage systems;
- extra dashboards.

Those are valuable **later**, but they make the base deployment harder to troubleshoot.

v7 keeps the baseline to:

```text
Ubuntu
  |
containerd
  |
kubeadm / kubelet / kubectl
  |
Calico
  |
local-path
```

The intent is that a learner can understand the cluster before adding observability, ingress, Helm, operators or application workloads.

---

# 18. Security notes

This is a **lab**, not a production cluster.

The design deliberately uses:

- a shared lab SSH account;
- passwordless sudo;
- an SSH private key stored on the admin machine;
- a single control-plane endpoint;
- node-local storage;
- public internet downloads during bootstrap.

Keep the VMs on an appropriate lab network.

Do not expose Kubernetes TCP 6443 to the public internet.

Do not put a real production credential in `lab.conf`.

If a temporary password is required:

```bash
SSH_PASSWORD="..."
```

use it only for preparation and then clear it.

The local kubeconfig under:

```text
.secrets/kubeconfig
```

has cluster-admin credentials and should be treated as sensitive.

---

# 19. Source/version references

The v7 defaults are intentionally based on current upstream references available when this solution was created.

Kubernetes' current kubeadm installation documentation is for the v1.37 minor release and uses the `pkgs.k8s.io` per-minor repository model. The same documentation notes the legacy `apt.kubernetes.io` repository is frozen and that current Kubernetes releases should use the newer repositories.

Containerd configuration follows the current Kubernetes runtime guidance, including the systemd cgroup driver and the different containerd 1.x/2.x configuration locations.

Calico is pinned to v3.32.2 in this lab. The upstream v3.32.2 `calico.yaml` documents `CALICO_IPV4POOL_CIDR` as the initial default IPv4 pool and notes that it should fall within the Kubernetes cluster CIDR.

The local-path provisioner is pinned to v0.0.37.

For a lab, pinning the URLs in configuration provides a deliberate, readable version boundary. Change those values explicitly when you want a new baseline.

Upstream references:

- Kubernetes kubeadm installation: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- Kubernetes container runtimes: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
- Calico manifest: https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/calico.yaml
- local-path stable manifest: https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.37/deploy/local-path-storage.yaml

---

# 20. Quick reference

### First setup

```bash
cd "$HOME/k8slabs/k8slabs/kuberneteslab/v7_chatgpt"
nano lab.conf
chmod +x ./*.sh
./check-lab.sh
./00_prepare-nodes.sh
./deploy-lab.sh
```

### Every new exercise

```bash
./reset-lab.sh
./deploy-lab.sh
```

### Inspect

```bash
./status-lab.sh
```

### Get kubeconfig

```bash
./fetch-kubeconfig.sh
export KUBECONFIG="$PWD/.secrets/kubeconfig"
kubectl get nodes -o wide
```

---

# 21. Summary

The v7 architecture is deliberately:

```text
                   ADMIN / WSL / LINUX
                          |
              +-----------+-----------+
              |           |           |
             SSH         SSH         SSH
              |           |           |
        +-----------+ +-----------+ +-----------+
        |  control  | |  worker01 | |  worker03 |
        | .51       | | .52       | | .53       |
        +-----------+ +-----------+ +-----------+
              |
            kubeadm
              |
        Kubernetes API
              |
        +-----+------+
        |            |
     Calico      local-path
```

The important operational property is:

```text
VM lifecycle != Kubernetes lifecycle
```

The VMs are persistent.

The Kubernetes cluster is disposable.

That separation makes the lab easy to reset and redeploy repeatedly without making the underlying Hyper-V environment part of the automation.
