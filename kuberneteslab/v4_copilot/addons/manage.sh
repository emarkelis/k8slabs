#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMPONENTS=(
    calico
    helm
    storage
    monitoring
    otel
)

echo
echo "====================================="
echo " Kubernetes Addon Manager"
echo "====================================="
echo

echo "1) Install"
echo "2) Remove"
echo "3) Upgrade"
echo "4) Validate"

read -rp "Select Action: " ACTION

echo
echo "Available Components"
echo

for i in "${!COMPONENTS[@]}"
do
    echo "$((i+1))) ${COMPONENTS[$i]}"
done

echo
read -rp "Select Component: " CHOICE

COMPONENT="${COMPONENTS[$((CHOICE-1))]}"

case "${ACTION}" in
    1)
        "${SCRIPT_DIR}/${COMPONENT}.sh" install
        ;;
    2)
        "${SCRIPT_DIR}/${COMPONENT}.sh" remove
        ;;
    3)
        "${SCRIPT_DIR}/${COMPONENT}.sh" upgrade
        ;;
    4)
        "${SCRIPT_DIR}/${COMPONENT}.sh" validate
        ;;
    *)
        echo "Invalid selection"
        exit 1
        ;;
esac
