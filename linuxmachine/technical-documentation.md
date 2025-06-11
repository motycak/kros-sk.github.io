# Technická dokumentácia

Popis technického riešenia pre rozbehanie kontajnerizovaných build agentov na Linuxových mašinách.

## Použité technológie

### Kubernetes Cluster (K3s)

Pre cluster je použitá K3s, ktorá je odľahčená verzia Kubernetes.

### KEDA (Kubernetes Event-driven Autoscaling)

KEDA poskytuje automatické škálovanie pre Kubernetes. My konkrétne používame škálovanie na základe počtu čakajúcich úloh v Azure DevOps.

**Použité KEDA objekty:**

- **ScaledObject**: Definuje autoscaling pravidlá
- **TriggerAuthentication**: Autentifikácia pre externé systémy

### Helm

Helm pomáha s nasadením a správou aplikácií v Kubernetes. Použitý na vytváranie agentov pre pooly. Dokážeme si s ním prispôsobovať kubernetes manifesty pre rôzne pooly.

## Súbory a ich funkcie

### Docker súbory

#### [`azure-agent-linux.dockerfile`](./azure-agent-linux.dockerfile)

Definuje Docker image pre Azure DevOps build agentov

- Vytvára Ubuntu 22.04 základný image
- Inštaluje všetky potrebné nástroje:
  - .NET SDK verzie 3.1, 5.0, 6.0, 7.0, 8.0
  - Node.js (LTS verzia)
  - PowerShell a Azure PowerShell moduly
  - Azure CLI s azure-devops extension
  - Kubectl
  - Git
  - Newman
- Nastavuje slovenskú lokalizáciu a časovú zónu
- Konfiguruje cache priečinky pre Cypress, npm, NuGet a Nx
- Inštaluje .NET global tools (dotnet-affected, Kros.DummyData.Initializer, Kros.VariableSubstitution)
- Kopíruje a spúšťa `start-k8s.sh` skript

#### [`start-k8s.sh`](./start-k8s.sh)

Hlavný inicializačný skript pre Kubernetes agentov

- Kontroluje povinné environment premenné (AZP_URL, AZURE_PAT_TOKEN, AZP_AGENT_NAME, AZP_POOL)
- Vytvára workdir pre agenta
- Odstraňuje existujúcu konfiguráciu agenta (ak existuje)
- Sťahuje najnovšiu verziu Azure Pipelines agenta z GitHub releases
- Konfiguruje agenta pre pripojenie k Azure DevOps
- Spúšťa agenta a spravuje jeho životný cyklus
- Obsahuje cleanup funkciu pre správne ukončenie agenta

### Helm Chart súbory

Nachádzajú sa v priečinku [`charts/build-agents-chart/`](./charts/build-agents-chart/). Tieto súbory sa prekopírujú na mašinu do vytvoreného Helm chart folderu. Vytvárane cez `helm create build-agents-chart`.

#### Templates

Helm templates sú rozdelené do menších súborov podľa použitých objektov:

**[`charts/build-agents-chart/templates/pvc.yaml`](./charts/build-agents-chart/templates/pvc.yaml)**

- **PersistentVolumeClaim**: Vytvára 100Gi storage pre cache agentov

**[`charts/build-agents-chart/templates/trigger-auth.yaml`](./charts/build-agents-chart/templates/trigger-auth.yaml)**

- **TriggerAuthentication**: Konfiguruje autentifikáciu pre KEDA s Azure PAT tokenom

**[`charts/build-agents-chart/templates/configmap.yaml`](./charts/build-agents-chart/templates/configmap.yaml)**

- **ConfigMap**: Definuje variables pre agenta (AZP_URL, AZP_POOL, AzurePS verzia)

**[`charts/build-agents-chart/templates/statefulset.yaml`](./charts/build-agents-chart/templates/statefulset.yaml)**

- **StatefulSet**: Hlavný objekt pre spustenie agentov s:
  - Konfiguráciou image z Azure Container Registry (obsahuje image z [`azure-agent-linux.dockerfile`](./azure-agent-linux.dockerfile))
  - Environment premennými a secrets
  - Volume mount pre cache
  - Image pull secrets pre Azure Container Registry

**[`charts/build-agents-chart/templates/service.yaml`](./charts/build-agents-chart/templates/service.yaml)**

- **Service**: Headless service pre StatefulSet

**[`charts/build-agents-chart/templates/scaled-object.yaml`](./charts/build-agents-chart/templates/scaled-object.yaml)**

- **ScaledObject**: KEDA objekt pre autoscaling na základe Azure DevOps queue

#### [`charts/build-agents-chart/values/`](./charts/build-agents-chart/values/) súbory

Konfiguračné súbory pre rôzne typy agent poolov

- `values-default.yaml` - Default agent pool
- `values-build-be.yaml` - Build BE agent pool
- `values-build-fe.yaml` - Build FE agent pool
- `values-deploy-be.yaml` - Deploy BE agent pool
- `values-deploy-fe.yaml` - Deploy FE agent pool

**Konfigurácia obsahuje**:

- Názov poolu a základný názov používaný pre názvy agentov
- Počet replík a autoscaling parametre
- Image repository a tag (image z nášho privátneho registry [krossk](https://portal.azure.com/#@kros.sk/resource/subscriptions/0f009b83-9652-4e0f-b891-2e6d816ecb88/resourcegroups/esw-shared-rsg/providers/microsoft.containerregistry/registries/krossk/overview))

## Bezpečnosť

### Autentifikácia a autorizácia

**Azure DevOps PAT Token:**

Potrebné vytvoriť prístupový token do Azure Devops. Token sa potom pridáva do secrets.

- Scope: `Read & manage` pre Agent Pools

**Azure Container Registry:**

Potrebné vytvoriť Service Principal pre náš privátny Azure Container Registry. [krossk](https://portal.azure.com/#@kros.sk/resource/subscriptions/0f009b83-9652-4e0f-b891-2e6d816ecb88/resourcegroups/esw-shared-rsg/providers/microsoft.containerregistry/registries/krossk/overview). Pridáme mu rolu `AcrPull` aby mohol čítať docker image pre build agentov z registry.

- Service Principal s `AcrPull` rolou

### Vytváranie secretov

V podoch potrebujeme pracovať s citlivými údajmi, preto je potrebné vytvoriť tieto secrets:

1. **azure-pat-token**: Azure DevOps PAT
2. **devextreme-key**: DevExtreme licenčný kľúč
3. **acr-secret**: Azure Container Registry credentials

### Cache optimalizácia

Cache sa zdieľa medzi všetkými agentmi a poolmi.

**Persistent Volume Claim:**

- 100 GB storage pre cache
- ReadWriteOnce access mode (pre K3s)
- local-path storage class

**Cache priečinky:**

- Cypress cache: `/opt/Agents/cache/cypress`
- NPM cache: `/opt/Agents/cache/npm`
- NuGet cache: `/opt/Agents/cache/nuget`
- Nx cache: `/opt/Agents/cache/nx`

## Deployment proces

Kompletné príkazy sú pri rozbehávaní agentov v [README.md](./README.md).
Potrebujeme aby boli splnené nasledujúce podmienky:

- Rozbehaný Kubernetes cluster (K3s)
- Aktuálny Docker image puhsnutý na našom registry
- Prístupové práva pre privátny registry [krossk](https://portal.azure.com/#@kros.sk/resource/subscriptions/0f009b83-9652-4e0f-b891-2e6d816ecb88/resourcegroups/esw-shared-rsg/providers/microsoft.containerregistry/registries/krossk/overview)
- Nastavené kubernetes secrets
- Helm chart priečinok nachystaný s aktuálnymi templates a values

Ak už splníme všetky podmienky, tak môžeme vytvárat/upravovať/mazat pooly pomocou Helm príkazov (`helm install`, `helm upgrade`, `helm delete`). Prípadne rollback cez `helm rollback` ak sa po úpravach niečo pokazilo.

## Monitoring

Monitorovanie aktuálneho stavu agentov a poolov môžeme v skratke cez:

```bash
kubectl get pods -n build-agents
kubectl get pvc -n build-agents
kubectl get configmap -n build-agents
kubectl get scaledobject -n build-agents
helm ls -n build-agents
```

Prehľadnejšie monitorovanie môžeme dosiahnuť cez [k9s](https://k9scli.io/).
