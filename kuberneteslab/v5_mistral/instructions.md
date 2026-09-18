# v5_mistral Kubernetes Lab - Setup Instructions

---

## 📁 **File List**

| File | Purpose | Canvas Identifier |
|------|---------|-------------------|
| **[README.md](sandbox/v4_mistral_k8s_lab)** | Documentation, architecture, and usage instructions | `v4_mistral_k8s_lab` |
| **[lab.conf](sandbox/v4_mistral_lab_conf)** | Central configuration file (edit this!) | `v4_mistral_lab_conf` |
| **lib/common.sh** | Shared functions for all scripts | `v4_mistral_common_sh` |
| **00_prepare-nodes.sh** | One-time setup for SSH keys and passwordless sudo | `v4_mistral_00_prepare_nodes` |
| **01_bootstrap-node.sh** | Installs dependencies (containerd, kubeadm, kubelet) on each node | `v4_mistral_01_bootstrap_node` |
| **02_reset-node.sh** | Wipes Kubernetes state on a node | `v4_mistral_02_reset_node` |
| **03_init-control.sh** | Initializes the control plane | `v4_mistral_03_init_control` |
| **04_join-workers.sh** | Joins worker nodes to the cluster | `v4_mistral_04_join_workers` |
| **05_cluster-components.sh** | Installs Calico CNI and local-path-provisioner | `v4_mistral_05_cluster_components` |
| **deploy-lab.sh** | **Main entry point**: Deploys or redeploys the entire lab | `v4_mistral_deploy_lab` |
| **reset-lab.sh** | **Reset entry point**: Wipes Kubernetes state (VMs stay running) | `v4_mistral_reset_lab` |
| **fetch-kubeconfig.sh** | Copies `kubeconfig` to your admin machine | `v4_mistral_fetch_kubeconfig` |

---

## 🚀 **How to Use**

### 1. **Create the Directory Structure**
```bash
mkdir -p ~/k8slabs/kuberneteslab/v4_mistral/lib
```

### 2. **Download the Files**
For each canvas above, copy the content into the corresponding file in `~/k8slabs/kuberneteslab/v4_mistral/`.

### 3. **Make Scripts Executable**
```bash
chmod +x ~/k8slabs/kuberneteslab/v4_mistral/*.sh
chmod +x ~/k8slabs/kuberneteslab/v4_mistral/lib/*.sh
```

### 4. **Edit `lab.conf`**
Update the configuration file with your actual values:
- `SSH_USER`
- `SSH_PASSWORD` (only for `00_prepare-nodes.sh`)
- `SSH_KEY_PATH`
- `K8S_VERSION`
- Node IPs and hostnames

### 5. **Run the Lab**
```bash
cd ~/k8slabs/kuberneteslab/v4_mistral

# One-time setup (if SSH keys are not already configured)
./00_prepare-nodes.sh

# Deploy the cluster
./deploy-lab.sh

# Access the cluster
./fetch-kubeconfig.sh
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

### 6. **Reset and Redeploy**
```bash
# Reset the cluster (VMs remain running)
./reset-lab.sh

# Redeploy
./deploy-lab.sh
```

---

## 🎯 **Key Features**

✅ **Idempotent**: All scripts can be rerun safely.
✅ **Beginner-friendly**: Minimal commands, clear feedback.
✅ **Configuration-driven**: Edit only `lab.conf`.
✅ **Non-destructive**: VMs stay running; only internal state is modified.
✅ **Ubuntu 26.04 LTS**: Fully compatible.
