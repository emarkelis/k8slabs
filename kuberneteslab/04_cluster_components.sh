#!/bin/bash

set -e

CALICO_URL="https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml"

LOCAL_PATH_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"

echo
echo "======================================="
echo " Kubernetes Component Manager"
echo "======================================="
echo
echo "1) Install"
echo "2) Remove"

read -p "Choice: " ACTION

echo
echo "Components:"
echo "1) Calico"
echo "2) Helm"
echo "3) StorageClass"
echo "4) Monitoring + OTel"

read -p "Component: " COMPONENT

#
# CALICO
#

if [[ "$COMPONENT" == "1" ]]
then

    if [[ "$ACTION" == "1" ]]
    then

        kubectl apply -f ${CALICO_URL}

    else

        kubectl delete -f ${CALICO_URL}

    fi
fi

#
# HELM
#

if [[ "$COMPONENT" == "2" ]]
then

    if [[ "$ACTION" == "1" ]]
    then

        curl \
        https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
        | bash

    else

        sudo rm -f /usr/local/bin/helm
    fi
fi

#
# STORAGECLASS
#

if [[ "$COMPONENT" == "3" ]]
then

    if [[ "$ACTION" == "1" ]]
    then

        kubectl apply -f ${LOCAL_PATH_URL}

        kubectl patch storageclass local-path \
        -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

    else

        kubectl delete -f ${LOCAL_PATH_URL}
    fi
fi

#
# MONITORING
#

if [[ "$COMPONENT" == "4" ]]
then

    helm repo add prometheus-community \
        https://prometheus-community.github.io/helm-charts

    helm repo add open-telemetry \
        https://open-telemetry.github.io/opentelemetry-helm-charts

    helm repo update

    if [[ "$ACTION" == "1" ]]
    then

        kubectl create namespace monitoring \
            --dry-run=client -o yaml \
            | kubectl apply -f -

        helm upgrade --install monitoring \
            prometheus-community/kube-prometheus-stack \
            -n monitoring

        helm upgrade --install otel \
            open-telemetry/opentelemetry-collector \
            -n monitoring

    else

        helm uninstall monitoring -n monitoring || true
        helm uninstall otel -n monitoring || true

        kubectl delete ns monitoring || true
    fi
fi

echo
echo "Done."
