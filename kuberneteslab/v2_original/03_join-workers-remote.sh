#!/bin/bash

WORKERS=("worker01" "worker02")

JOIN_CMD=$(kubeadm token create --print-join-command)

for NODE in "${WORKERS[@]}"
do
    scp /dev/null ${NODE}:/tmp/kubeadm-join.sh

    ssh ${NODE} "
        echo '$JOIN_CMD' > /tmp/kubeadm-join.sh
        chmod +x /tmp/kubeadm-join.sh
        sudo bash /tmp/kubeadm-join.sh
    "
done
