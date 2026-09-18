apiVersion: networking.k8s.io/v1
kind: Ingress

metadata:
  name: ${INGRESS_NAME}

spec:

  rules:
  - host: ${HOST}

    http:
      paths:

      - path: /
        pathType: Prefix

        backend:

          service:
            name: ${SERVICE_NAME}

            port:
              number: 80
