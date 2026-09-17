# Fully Configurable Kubernetes Lab (v3 by Gemini)

Centralized configuration-driven setup for Kubernetes on Ubuntu Hyper-V VMs.



This directory contains an automated, repeatable toolkit designed to build, reset, and redeploy an enterprise-like multi-node Kubernetes cluster on Hyper-V virtual machines running Ubuntu.

The solution uses a central configuration file (`config.env`), allowing you to adapt IP addresses, hostnames, SSH keys, usernames, and Kubernetes versions without modifying the core shell scripts.

---

## 1. Cluster Architecture & Layout

| Role | Hostname (Default) | IP Address (Default) | Specs (Recommended) |
| :--- | :--- | :--- | :--- |
| **Control Plane** | `control` | `192.168.178.51` | 2 vCPU, 4 GB RAM, 20 GB Disk |
| **Worker Node 1** | `worker01` | `192.168.178.52` | 2 vCPU, 4 GB RAM, 20 GB Disk |
| **Worker Node 2** | `worker03` | `192.168.178.53` | 2 vCPU, 4 GB RAM, 20 GB Disk |

---

## 2. Directory & Script Map

* **`config.env`**: Central configuration file for environment variables.
* **`README.md`**: Complete lab documentation and instructions.
* **`00_reset-node.sh`**: Teardown script (cleans K8s state, virtual interfaces, and iptables rules).
* **`01_bootstrap-k8s-node.sh`**: Installs container runtime, sysctl settings, and K8s packages.
* **`02_build-cluster.sh`**: Initializes kubeadm on control plane & applies Flannel CNI.
* **`03_join-workers.sh`**: Generates dynamic join tokens & joins workers over SSH.
* **`04_cluster_components.sh`**: Deploys Metrics-Server, Local-Path Storage, & Ingress NGINX.
* **`deploy-all.sh`**: Master orchestrator script (end-to-end automation).

---

## 3. Environment Prerequisites

Before executing the deployment, ensure your Hyper-V virtual machines and host account meet the following requirements:

### A. Network & OS Configuration
* All VMs must run **Ubuntu Linux** with internet access.
* Static IP addresses must be configured on all nodes (or DHCP reservations assigned).
* Hostnames must resolve or be reachable via IP addresses.

### B. Configure Passwordless SSH (Control Plane -> Workers)
The orchestration scripts run from the **Control Plane** and push configurations to workers over SSH.

1. On the **Control Plane** (`192.168.178.51`), generate an SSH key if you don't already have one:
   ```bash
   ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
   ```

2. Copy the key to all worker nodes:

```bash
ssh-copy-id ubuntu@192.168.178.52
ssh-copy-id ubuntu@192.168.178.53
```

3. Test SSH connections without being prompted for a password: (sample code)
   ```bash
   ssh ubuntu@192.168.178.52 "hostname"
   ssh ubuntu@192.168.178.53 "hostname"
   ``` 

### C. Configure Passwordless Sudo
Ensure your lab user (ubuntu or equivalent) has passwordless sudo privileges on all machines.
On each machine, run:
```bash
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/lab-user-nopasswd
```  

## 4. Configuration Setup (config.env)
Clone or copy the v3/ scripts to your Control Plane node. 
Open config.env and update the variables to match your environment:
** Example **
```bash
# Central Lab Configuration

# --- User & SSH Credentials ---
SSH_USER="ubuntu"
SSH_KEY_PATH="$HOME/.ssh/id_rsa"

# --- Repository & Paths ---
LAB_REPO_URL="[https://github.com/emarkelis/k8slabs](https://github.com/emarkelis/k8slabs)"
LAB_DIR="/home/ubuntu/k8slabs/kuberneteslab/v3"

# --- Kubernetes Settings ---
K8S_VERSION="v1.31"
POD_CIDR="10.244.0.0/16"

# --- Control Plane Node ---
CONTROL_NAME="control"
CONTROL_IP="192.168.178.51"

# --- Worker Nodes ---
WORKER_IPS=("192.168.178.52" "192.168.178.53")
WORKER_NAMES=("worker01" "worker03")
```
## 5. Deployment Options
### Option A: Fully Automated One-Click Deployment (Recommended)
Run the master orchestrator script from the Control Plane node:

```bash
./deploy-all.sh
```

What deploy-all.sh does automatically:

1. Sets the hostname of the Control Plane node.
2. Runs 01_bootstrap-k8s-node.sh locally on the Control Plane.
3. Copies all deployment scripts to /tmp/k8s-v3/ on each worker node over SSH.
4. Executes 01_bootstrap-k8s-node.sh remotely on worker nodes.
5. Runs 02_build-cluster.sh to initialize the control plane and set up Flannel CNI.
6. Runs 03_join-workers.sh to fetch dynamic tokens and join worker nodes.
7. Runs 04_cluster_components.sh to deploy Metrics Server, Local Storage, and Ingress.

### Option B: Step-by-Step Manual Deployment
If you want to observe or debug each phase individually, run the steps manually:

#### Step 1: Bootstrap Prerequisites on All Nodes
On Control Node (192.168.178.51):
```Bash
./01_bootstrap-k8s-node.sh
```
On Worker Node 1 (192.168.178.52) & Worker Node 2 (192.168.178.53):

```bash
# You can run it directly on each node, or execute via SSH from control:
ssh ubuntu@192.168.178.52 'bash -s' < ./01_bootstrap-k8s-node.sh
ssh ubuntu@192.168.178.53 'bash -s' < ./01_bootstrap-k8s-node.sh
```
#### Step 2: Initialize Control Plane
On the Control Node:
```bash
./02_build-cluster.sh
```

#### Step 3: Join Worker Nodes
On the Control Node:
```bash
./03_join-workers.sh
```

#### Step 4: Install Core Cluster Components
On the Control Node:
```bash
./04_cluster_components.sh
```
## 6. Teardown, Reset, and Redeploy Workflow
You do not need to destroy or recreate your Hyper-V VMs to reset the environment. The 00_reset-node.sh script removes Kubernetes state, CNI bridges, iptables rules, and restores containerd/kubelet to a fresh baseline.

How to Reset the Entire Cluster in Seconds
Run the reset commands from the Control Node:

1. Source configuration settings
```bash
source config.env
```

2. Reset worker nodes remotely over SSH
```bash
for IP in "${WORKER_IPS[@]}"; do
  echo "==> Resetting worker: ${IP}"
  ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${SSH_USER}@${IP}" 'bash -s' < ./00_reset-node.sh
done
```
3. Reset the control plane node locally
```bash
./00_reset-node.sh
```

Immediate Redeployment
After resetting, rebuild the cluster with a single command:
```bash
./deploy-all.sh
```

## 7. Cluster Verification & Testing
Verify that your cluster and components are running correctly:

### A. Check Node Statu
```bash
kubectl get nodes -o wide
```
Expected output: All 3 nodes (control, worker01, worker03) should display state Ready.

### B. Check Core System Pods
```bash
kubectl get pods -n kube-system
```
Expected output: Flannel, CoreDNS, kube-apiserver, kube-proxy, and Metrics Server pods should be in Running state.

### C. Test Metrics Server
```bash
kubectl top nodes
kubectl top pods -A
```
### D. Verify Storage Class
```bash
kubectl get storageclass
```
Expected output: local-path should be listed and marked as (default).

### E. Verify Ingress Controller
```bash
kubectl get pods -n ingress-nginx
```

##8. Troubleshooting
** Worker Node Fails to Join (kubeadm join error): **
Ensure port 6443 on the Control Plane is accessible and not blocked by ufw or Windows Hyper-V Virtual Switch firewalls. Run sudo ufw disable on all nodes if needed.

** Container Runtime Errors (cgroup mismatch): **
Containerd is preconfigured in 01_bootstrap-k8s-node.sh with SystemdCgroup = true. If containerd fails to start, verify using sudo systemctl status containerd.

** CNI / Flannel Network Interface Issues: **
If nodes fail to reach Ready status, ensure swap is completely disabled (sudo swapoff -a) and kernel module br_netfilter is loaded (lsmod | grep br_netfilter).
