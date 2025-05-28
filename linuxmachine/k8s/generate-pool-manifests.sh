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
        env:
        - name: AZP_AGENT_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
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
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: build-agent-keda-${pool}
spec:
  scaleTargetRef:
    name: build-agent-${pool}
    kind: Deployment
  pollingInterval: 30
  cooldownPeriod: 300
  minReplicaCount: ${min}
  maxReplicaCount: ${max}
  triggers:
  - type: azure-pipelines
    metadata:
      organizationURLFromEnv: "AZURE_DEVOPS_URL"
      personalAccessTokenFromEnv: "AZURE_PAT_TOKEN"
      targetPipelinesQueueLength: "1"
      activationThreshold: "1"
      targetPipelinesPoolID: "${pool}"
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