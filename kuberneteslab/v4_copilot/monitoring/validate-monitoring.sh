#!/usr/bin/env bash

set -euo pipefail

echo
echo "Checking Monitoring Stack"

kubectl get pods -n monitoring

echo
echo "Grafana"

kubectl get svc -n monitoring | grep grafana

echo
echo "Prometheus"

kubectl get svc -n monitoring | grep prometheus

echo
echo "OpenTelemetry"

kubectl get pods -n monitoring | grep otel || true
