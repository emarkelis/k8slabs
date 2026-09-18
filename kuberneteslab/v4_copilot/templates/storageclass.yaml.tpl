apiVersion: storage.k8s.io/v1
kind: StorageClass

metadata:
  name: ${SC_NAME}

provisioner: rancher.io/local-path
