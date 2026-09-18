#!/usr/bin/env bash

set -euo pipefail

helm uninstall otel -n monitoring || true
