#!/bin/bash

set -e

echo "Cleaning application workloads..."

kubectl delete deployment --all -A --ignore-not-found=true
kubectl delete statefulset --all -A --ignore-not-found=true
kubectl delete daemonset --all -A --ignore-not-found=true
kubectl delete job --all -A --ignore-not-found=true
kubectl delete cronjob --all -A --ignore-not-found=true
kubectl delete ingress --all -A --ignore-not-found=true

echo "Cleaning services except kubernetes service..."

for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}')
do
    kubectl get svc -n "$ns" --no-headers 2>/dev/null \
    | awk '$1 != "kubernetes" {print $1}' \
    | xargs -r kubectl delete svc -n "$ns"
done

echo "Cleanup completed."

echo
echo "Remaining resources:"
kubectl get nodes
kubectl get storageclass
kubectl get pvc -A
kubectl get pods -n calico-system
