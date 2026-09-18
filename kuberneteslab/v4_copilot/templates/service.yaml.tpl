apiVersion: v1
kind: Service

metadata:
  name: ${SERVICE_NAME}

spec:

  selector:
    app: ${APP_NAME}

  ports:
  - port: 80
    targetPort: 80

  type: ClusterIP
