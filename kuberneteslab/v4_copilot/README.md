# Kubernetes Lab Platform v4

## Overview

Kubernetes Lab Platform v4 is a fully configurable, repeatable Kubernetes lab environment designed for Hyper-V based Ubuntu virtual machines.

The solution allows you to:

- Deploy a Kubernetes cluster repeatedly without recreating VMs
- Reset the cluster at different levels
- Install and remove optional components
- Use only official software sources
- Manage configuration from centralized files
- Support monitoring and observability from day one
- Support OpenTelemetry collectors
- Practice CKA, CKAD, CKS and general Kubernetes administration

The Kubernetes cluster is built using:

- kubeadm
- containerd
- Calico
- Local Path Provisioner
- Helm
- Prometheus
- Grafana
- OpenTelemetry Collector

---

# Architecture

## Physical Architecture example

```text
                     Hyper-V Host
                            |
        ---------------------------------------
        |                                     |
        |                                     |
        ▼                                     ▼

     VMware/Hyper-V Virtual Network

        +----------------------------+
        |          control           |
        |     192.168.178.51        |
        |      Kubernetes API        |
        +-------------+--------------+
                      |
                      |
      ---------------------------------------
      |                                     |
      |                                     |
      ▼                                     ▼

+---------------------+      +----------------------+
|      worker01       |      |      worker02        |
|   192.168.178.52    |      |   192.168.178.53     |
+---------------------+      +----------------------+
```

---

## Kubernetes Networking

```text
CNI:
    Calico

Pod Network:
    10.244.0.0/16

Service Network:
    10.96.0.0/12
```

---

## Observability Architecture

```text
            Applications
                   |
                   ▼

       OpenTelemetry Collector
                   |
                   ▼

              Prometheus
                   |
                   ▼

               Grafana
```

---

## Storage Architecture

```text
Applications
      |
      ▼

PersistentVolumeClaim
      |
      ▼

Local Path Provisioner
      |
      ▼

Worker Node Filesystem
```

---

# Repository Structure

```text
v4/
│
├── README.md
│
├── config/
│   ├── cluster.conf
│   ├── credentials.conf
│   ├── versions.conf
│   └── addons.conf
│
├── lib/
│   ├── common.sh
│   ├── ssh.sh
│   ├── logging.sh
│   ├── validation.sh
│   └── versions.sh
│
├── bootstrap/
│   ├── bootstrap-node.sh
│   ├── install-containerd.sh
│   └── install-kubernetes.sh
│
├── cluster/
│   ├── build.sh
│   ├── join-workers.sh
│   ├── validate.sh
│   ├── reset.sh
│   └── kubeadm-config.template
│
├── addons/
│   ├── manage.sh
│   ├── calico.sh
│   ├── helm.sh
│   ├── storage.sh
│   ├── monitoring.sh
│   └── otel.sh
│
├── monitoring/
│   ├── values/
│   ├── dashboards/
│   ├── alerts/
│   ├── install-monitoring.sh
│   ├── remove-monitoring.sh
│   ├── install-otel.sh
│   ├── remove-otel.sh
│   └── validate-monitoring.sh
│
├── validation/
│   ├── validate-cluster.sh
│   ├── validate-network.sh
│   ├── validate-storage.sh
│   ├── validate-monitoring.sh
│   └── validate-workers.sh
│
├── templates/
│   ├── kubeadm-config.yaml.tpl
│   ├── namespace.yaml.tpl
│   ├── deployment.yaml.tpl
│   ├── service.yaml.tpl
│   ├── ingress.yaml.tpl
│   ├── pvc.yaml.tpl
│   └── storageclass.yaml.tpl
│
└── logs/
```

---

# Prerequisites

## Operating System

Each VM:

```text
Ubuntu 26.04 LTS
```

Recommended:

```text
2 vCPU
4 GB RAM
20 GB Disk
```

Minimum:

```text
2 vCPU
2 GB RAM
15 GB Disk
```

---

## Network Connectivity

Verify:

```bash
ping control
ping worker01
ping worker02
```

Verify SSH:

```bash
ssh ubuntu@192.168.178.52

ssh ubuntu@192.168.178.53
```

---

## Passwordless SSH

Generate key:

```bash
ssh-keygen -t ed25519
```

Copy to workers:

```bash
ssh-copy-id ubuntu@192.168.178.52

ssh-copy-id ubuntu@192.168.178.53
```

Test:

```bash
ssh ubuntu@192.168.178.52 hostname

ssh ubuntu@192.168.178.53 hostname
```

---

## Passwordless Sudo

Run on all nodes:

```bash
echo "$USER ALL=(ALL) NOPASSWD:ALL" \
| sudo tee /etc/sudoers.d/k8s-lab
```

Validate:

```bash
sudo -n true
```

---

# Configuration

## cluster.conf

Contains:

```bash
CONTROL_HOST

CONTROL_IP

WORKER_HOSTS

WORKER_IPS

POD_CIDR

NETWORK_INTERFACE
```

Example:

```bash
CONTROL_HOST="control"

CONTROL_IP="192.168.178.51"

WORKER_HOSTS=(
    "worker01"
    "worker02"
)

WORKER_IPS=(
    "192.168.178.52"
    "192.168.178.53"
)
```

---

## credentials.conf

Contains:

```bash
AUTH_MODE

SSH_USER

SSH_PASS

SSH_KEY
```

Recommended:

```bash
AUTH_MODE="key"

SSH_USER="ubuntu"

SSH_KEY="$HOME/.ssh/id_ed25519"
```

---

## versions.conf

Supports:

```bash
VERSION_MODE="latest"
```

or

```bash
VERSION_MODE="pinned"
```

Example:

```bash
VERSION_MODE="latest"
```

---

## addons.conf

Controls optional features.

Example:

```bash
ENABLE_CALICO=true

ENABLE_STORAGE=true

ENABLE_HELM=true

ENABLE_MONITORING=true

ENABLE_OTEL=true
```

---

# Deployment Procedure

## Step 1

Clone repository.

```bash
git clone <your repo>

cd v4
```

---

## Step 2

Configure:

```bash
config/cluster.conf

config/credentials.conf

config/versions.conf

config/addons.conf
```

---

## Step 3

Bootstrap Nodes

Run on ALL nodes.

Control:

```bash
./bootstrap/bootstrap-node.sh
```

Worker01:

```bash
./bootstrap/bootstrap-node.sh
```

Worker02:

```bash
./bootstrap/bootstrap-node.sh
```

This installs:

```text
containerd

kubelet

kubeadm

kubectl
```

---

## Step 4

Create Control Plane

Run on:

```text
control
```

```bash
./cluster/build.sh
```

This will:

```text
Generate kubeadm configuration

Initialize Kubernetes

Configure kubectl

Install selected addons
```

---

## Step 5

Join Workers

Run:

```bash
./cluster/join-workers.sh
```

This will:

```text
Generate join token

Connect to workers

Join workers automatically
```

---

## Step 6

Install Addons

Interactive:

```bash
./addons/manage.sh
```

Or individually:

```bash
./addons/calico.sh install

./addons/storage.sh install

./addons/monitoring.sh install

./addons/otel.sh install
```

---

# Validation

## Cluster

```bash
./cluster/validate.sh
```

---

## Nodes

```bash
kubectl get nodes -o wide
```

Expected:

```text
control     Ready

worker01    Ready

worker02    Ready
```

---

## Pods

```bash
kubectl get pods -A
```

All critical pods should be:

```text
Running
```

---

## Storage

```bash
kubectl get storageclass
```

Expected:

```text
local-path (default)
```

---

## Monitoring

```bash
kubectl get pods -n monitoring
```

Expected:

```text
prometheus

grafana

alertmanager

otel
```

---

# Reset Procedures

The solution supports multiple reset levels.

---

## Level 1

Workloads Only

Removes:

```text
Deployments

StatefulSets

Jobs

DaemonSets
```

Leaves:

```text
Calico

Storage

Monitoring
```

---

## Level 2

Workloads + Addons

Removes:

```text
Applications

Calico

Storage

Monitoring

OTEL
```

Leaves:

```text
Kubernetes Control Plane
```

---

## Level 3

Cluster Reset

Runs:

```bash
kubeadm reset -f
```

Leaves:

```text
Ubuntu

containerd

Installed binaries
```

---

## Level 4

Factory Reset

Removes:

```text
Kubernetes state

etcd

CNI

kubelet state

cluster config
```

Leaves:

```text
Linux VM
```

---

# Monitoring

The monitoring stack installs:

```text
Prometheus

Grafana

AlertManager

Node Exporter

kube-state-metrics
```

Install:

```bash
./monitoring/install-monitoring.sh
```

Remove:

```bash
./monitoring/remove-monitoring.sh
```

Validate:

```bash
./monitoring/validate-monitoring.sh
```

---

# OpenTelemetry

Install:

```bash
./monitoring/install-otel.sh
```

Remove:

```bash
./monitoring/remove-otel.sh
```

Capabilities:

```text
OTLP HTTP

OTLP gRPC

Tracing

Metrics

Logs
```

---

# Upgrade Procedure

Update:

```bash
config/versions.conf
```

Run:

```bash
./addons/manage.sh
```

Select:

```text
Upgrade
```

for the desired component.

---

# Logging

Logs stored:

```text
logs/build

logs/reset

logs/addons

logs/validation
```

Examples:

```text
logs/build/build-20260313-120000.log

logs/reset/reset-20260314-091500.log
```

---

# Troubleshooting

## Worker Not Ready

Check:

```bash
kubectl describe node worker01
```

Check:

```bash
systemctl status kubelet
```

---

## Calico Problems

```bash
kubectl get pods -n calico-system
```

Check:

```bash
kubectl logs -n calico-system <pod>
```

---

## Storage Problems

```bash
kubectl get pvc

kubectl describe pvc
```

---

## Monitoring Problems

```bash
kubectl get pods -n monitoring
```

---

## Container Runtime Issues

```bash
systemctl status containerd

crictl info
```

---

# Design Principles

The v4 platform follows these principles:

- Configuration Driven
- Official Sources Only
- Idempotent Execution
- Repeatable Lab Builds
- Hyper-V Friendly
- Upgrade Ready
- Observable by Default
- OpenTelemetry Ready
- VM Persistence First

The virtual machines are treated as permanent infrastructure, while Kubernetes becomes disposable and fully reproducible.
