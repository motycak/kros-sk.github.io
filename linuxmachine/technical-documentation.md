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

## Bezpečnosť

### Autentifikácia a autorizácia

**Azure DevOps PAT Token:**

Potrebné vytvoriť prístupový token do Azure Devops.

- Scope: `Read & manage` pre Agent Pools

**Azure Container Registry:**

Potrebné vytvoriť Service Principal pre náš privátny Azure Container Registry. [krossk](https://portal.azure.com/#@kros.sk/resource/subscriptions/0f009b83-9652-4e0f-b891-2e6d816ecb88/resourcegroups/esw-shared-rsg/providers/microsoft.containerregistry/registries/krossk/overview). Pridáme mu rolu `AcrPull` aby mohol čítať docker image pre build agentov z registry.

- Service Principal s `AcrPull` rolou

### Vytváranie secretov

V podoch potrebujeme pracovať s citlivými údajmi, preto je potrebné vytvoriť tieto secrets:

1. **azure-pat-token**: Azure DevOps PAT
2. **devextreme-key**: DevExtreme licenčný kľúč
3. **acr-secret**: Azure Container Registry credentials

## Performance a optimalizácia

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