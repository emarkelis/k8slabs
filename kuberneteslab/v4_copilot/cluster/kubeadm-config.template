apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration

controlPlaneEndpoint: "${CONTROL_HOST}:6443"

networking:
  podSubnet: "${POD_CIDR}"

---
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration

localAPIEndpoint:
  advertiseAddress: "${CONTROL_IP}"
  bindPort: 6443

nodeRegistration:
  name: "${CONTROL_HOST}"
  criSocket: unix:///run/containerd/containerd.sock
