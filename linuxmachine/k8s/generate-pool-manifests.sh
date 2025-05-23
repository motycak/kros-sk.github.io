#!/bin/bash

# Konfigurácia poolov
declare -A pools=(
  ["build-be"]="2:6"  # min:max
  ["build-fe"]="2:4"
  ["deploy-be"]="1:3"
  ["deploy-fe"]="1:3"
  ["default"]="1:2"
)

# Generovanie manifestov pre každý pool
for pool in "${!pools[@]}"; do
  IFS=':' read -r min max <<< "${pools[$pool]}"
  
  # Vytvorenie manifestu pre pool
  cat > "build-agent-${pool}.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: build-agent-config-${pool}
data:
  AZURE_DEVOPS_URL: "https://dev.azure.com/kros-sk"
  AGENT_POOL_NAME: "${pool}"
---
apiVersion: v1
kind: Secret
metadata:
  name: azure-pat-token-${pool}
type: Opaque
data:
  AZURE_PAT_TOKEN: \${AZURE_PAT_TOKEN_BASE64}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: build-agent-${pool}
  labels:
    app: build-agent
    pool: ${pool}
spec:
  replicas: ${min}
  selector:
    matchLabels:
      app: build-agent
      pool: ${pool}
  template:
    metadata:
      labels:
        app: build-agent
        pool: ${pool}
    spec:
      containers:
      - name: build-agent
        image: azure-agent-linux:latest
        envFrom:
        - configMapRef:
            name: build-agent-config-${pool}
        - secretRef:
            name: azure-pat-token-${pool}
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "1000m"
            memory: "2Gi"
        volumeMounts:
        - name: agent-cache
          mountPath: /opt/Agents/cache
      volumes:
      - name: agent-cache
        persistentVolumeClaim:
          claimName: agent-cache-pvc-${pool}
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: build-agent-hpa-${pool}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: build-agent-${pool}
  minReplicas: ${min}
  maxReplicas: ${max}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: agent-cache-pvc-${pool}
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
  storageClassName: standard
EOF
done

echo "Manifesty boli vygenerované pre všetky pooly." 