# Nasadenie Build Agentov do Kubernetes

Tento dokument popisuje postup nasadenia build agentov do Kubernetes clusteru s automatickým škálovaním.

## Požiadavky

- Kubernetes cluster (minikube, AKS, alebo iný)
- kubectl nainštalovaný
- Docker image `azure-agent-linux:latest` dostupný v registry
- Azure PAT token s právami `Read & manage` pre scope `Agent Pools`

## Postup nasadenia

1. **Príprava PAT tokenu**

```bash
# Zakódovanie PAT tokenu do base64
echo -n "VAS_PAT_TOKEN" | base64
```

2. **Generovanie manifestov**

```bash
# Nastavenie práva na spustenie skriptu
chmod +x generate-pool-manifests.sh

# Spustenie generovania manifestov
./generate-pool-manifests.sh
```

3. **Úprava manifestov**

Pre každý vygenerovaný manifest `build-agent-{pool}.yaml`:
- Nahraďte `${AZURE_PAT_TOKEN_BASE64}` skutočnou base64 hodnotou PAT tokenu
- Upravte `storageClassName` podľa vašej Kubernetes infraštruktúry
- Prípadne upravte resource limity a requests podľa potrieb

4. **Nasadenie do Kubernetes**

```bash
# Vytvorenie namespace
kubectl create namespace build-agents

# Nasadenie všetkých poolov
for pool in build-be build-fe deploy-be deploy-fe default; do
  kubectl apply -f build-agent-${pool}.yaml -n build-agents
done
```

5. **Overenie nasadenia**

```bash
# Kontrola stavu deploymentov
kubectl get deployments -n build-agents

# Kontrola stavu podov
kubectl get pods -n build-agents

# Kontrola stavu HPA
kubectl get hpa -n build-agents
```

## Škálovanie

Každý pool má nastavené vlastné limity škálovania:
- build-be: 2-6 agentov
- build-fe: 2-4 agentov
- deploy-be: 1-3 agentov
- deploy-fe: 1-3 agentov
- default: 1-2 agentov

Škálovanie je automatické na základe využitia CPU a pamäte (80% threshold).

## Monitoring

Pre monitorovanie stavu agentov môžete použiť:

```bash
# Zobrazenie logov konkrétneho podu
kubectl logs -f <pod-name> -n build-agents

# Zobrazenie metrík HPA
kubectl describe hpa -n build-agents

# Zobrazenie využitia zdrojov
kubectl top pods -n build-agents
```

## Údržba

Pre aktualizáciu agentov:

```bash
# Aktualizácia image
kubectl set image deployment/build-agent-{pool} build-agent=azure-agent-linux:latest -n build-agents

# Rollback v prípade problémov
kubectl rollout undo deployment/build-agent-{pool} -n build-agents
```

## Odstránenie

Pre odstránenie všetkých poolov:

```bash
kubectl delete namespace build-agents
``` 