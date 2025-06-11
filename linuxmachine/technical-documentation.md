# Technická dokumentácia

Popis technického riešenia pre rozbehanie kontajnerizovaných build agentov na Linuxových mašinách.

## Použité technológie

- **Kubernetes**: K3s
- **Container Runtime**: Docker
- **Pool management**: Helm
- **Autoscaling**: KEDA
- **Registry**: Azure Container Registry
- **CI/CD**: Azure DevOps

## Detailná architektúra

### Kubernetes Cluster (K3s)

Pre cluster je použitá K3s, ktorá je odľahčená verzia Kubernetes.

### KEDA (Kubernetes Event-driven Autoscaling)

KEDA poskytuje automatické škálovanie pre Kubernetes. My konkrétne používame škálovanie na základe počtu čakajúcich úloh v Azure DevOps.

**Použité KEDA objekty:**

- **ScaledObject**: Definuje autoscaling pravidlá
- **TriggerAuthentication**: Autentifikácia pre externé systémy

### Docker Image Architektúra

Docker image sa vytvára na základe [azure-agent-linux.dockerfile](./azure-agent-linux.dockerfile). Na ktorom sa spúšťa [start-k8s.sh](./start-k8s.sh) skript, ktorý sa stará o pripojenie agenta k Azure DevOps a jeho spustenie.

### Helm Chart štruktúra

Všetky potrebné súbory pre vytvorenie Helm Chart sú v [build-agents-chart](./charts/build-agents-chart/).

```
build-agents-chart/
├── templates/
│   ├── pool-manifest.yaml
└── values/
    ├── values-build-be.yaml
    ├── values-build-fe.yaml
    ├── values-default.yaml
    ├── values-deploy-be.yaml
    └── values-deploy-fe.yaml
```

Tieto súbory sa prekopírujú z repozitára na Linuxové mašiny. Na základe nich potom vieme manažovať Agentové Pooly.

## Sieťová architektúra

### Porty a protokoly

- **6443**: Kubernetes API Server (HTTPS)
- **10250**: Kubelet API (HTTPS)
- **2379**: etcd (ak používaný)
- **9090**: KEDA Metrics Server
- **9000**: Portainer (voliteľne)

### Sieťové politiky

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: build-agents-network-policy
spec:
  podSelector:
    matchLabels:
      app: build-agents
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: build-agents
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
```

## Bezpečnostná architektúra

### Autentifikácia a autorizácia

**Azure DevOps PAT Token:**

- Scope: `Read & manage` pre Agent Pools
- Expirácia: 1 rok (odporúčané)
- Rotácia: Automatická cez Azure Key Vault (voliteľne)

**Azure Container Registry:**

- Service Principal s `AcrPull` rolou
- Automatická rotácia credentials

**Kubernetes RBAC:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: build-agents
  name: build-agents-role
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

### Secrets Management

**Typy secretov:**

1. **azure-pat-token**: Azure DevOps PAT
2. **devextreme-key**: DevExtreme licenčný kľúč
3. **acr-secret**: Azure Container Registry credentials

**Secret rotácia:**

```bash
# Rotácia PAT token
kubectl patch secret azure-pat-token -p='{"data":{"AZURE_PAT_TOKEN":"'$(echo -n $NEW_TOKEN | base64)'"}}'

# Rotácia ACR credentials
kubectl patch secret acr-secret -p='{"data":{"docker-password":"'$(echo -n $NEW_PASSWORD | base64)'"}}'
```

## Monitoring a observability

### Metriky

**Kubernetes metriky:**

- CPU a RAM využitie podov
- Počet replík deploymentov
- Stav podov (Running, Pending, Failed)

**KEDA metriky:**

- Počet čakajúcich úloh v Azure DevOps
- Autoscaling events
- Scaler latency

**Azure DevOps metriky:**

- Počet agentov v pooloch
- Úlohy za minútu
- Priemerný čas spracovania úlohy

### Logging

**Struktúra logov:**

```
/var/log/containers/
├── azure-agent-*.log
├── keda-*.log
└── k3s-*.log
```

**Log aggregation (voliteľne):**

- Fluentd/Fluent Bit
- Elasticsearch
- Kibana

### Alerting

**Kľúčové alerty:**

- Pod v Failed stave > 5 minút
- CPU využitie > 80% dlhšie ako 10 minút
- RAM využitie > 90%
- KEDA scaler nefunguje

## Performance a optimalizácia

### Resource Limits

**Pod resource limits:**

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

### Autoscaling konfigurácia

**KEDA ScaledObject optimalizácia:**

```yaml
spec:
  minReplicaCount: 0
  maxReplicaCount: 20
  pollingInterval: 30
  cooldownPeriod: 300
  triggers:
  - type: azure-pipelines
    metadata:
      targetPipelinesQueueLength: "1"
      activationThreshold: "1"
```

### Systémová optimalizácia

**Kernel parameters:**

```bash
# /etc/sysctl.conf
vm.swappiness=10
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
```

**Docker optimalizácia:**

```json
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

## Disaster Recovery

### Backup stratégia

**Kubernetes objekty:**

```bash
# Backup všetkých objektov v namespace
kubectl get all -n build-agents -o yaml > backup-$(date +%Y%m%d).yaml

# Backup Helm releases
helm list -n build-agents -o yaml > helm-releases-$(date +%Y%m%d).yaml
```

**Konfigurácia:**

- Helm values súbory v Git repozitári
- Docker images v Azure Container Registry
- Secrets v Kubernetes (zálohované cez velero)

### Recovery postup

1. **Obnovenie K3s clusteru:**

```bash
curl -sfL https://get.k3s.io | sh -
```

2. **Obnovenie namespace a objektov:**

```bash
kubectl create namespace build-agents
kubectl apply -f backup-YYYYMMDD.yaml
```

3. **Obnovenie Helm releases:**

```bash
helm install build-be /opt/Agents/agentCharts/build-agents-chart \
  --values /opt/Agents/agentCharts/build-agents-chart/values/values-build-be.yaml \
  --namespace build-agents
```

## Troubleshooting

### Časté problémy

**Agent sa nepripojí k Azure DevOps:**

```bash
# Kontrola PAT token
kubectl get secret azure-pat-token -n build-agents -o yaml

# Kontrola logov agenta
kubectl logs -f deployment/azure-agent -n build-agents
```

**KEDA neškáluje:**

```bash
# Kontrola ScaledObject
kubectl get scaledobject -n build-agents

# Kontrola KEDA logov
kubectl logs -f deployment/keda-operator -n keda
```

**Pod sa neštartuje:**

```bash
# Kontrola events
kubectl describe pod <pod-name> -n build-agents

# Kontrola resource limits
kubectl top pods -n build-agents
```

### Debug nástroje

**K9s:**

```bash
k9s -n build-agents
```

**Kubernetes CLI:**

```bash
# Základné informácie
kubectl get all -n build-agents

# Detailné informácie
kubectl describe deployment <deployment-name> -n build-agents

# Logy
kubectl logs -f <pod-name> -n build-agents
```

**Helm:**

```bash
# História release
helm history <release-name> -n build-agents

# Manifest diff
helm diff upgrade <release-name> /path/to/chart -n build-agents
```
