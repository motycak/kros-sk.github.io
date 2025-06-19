# Diagnóza a riešenie bottlenecku pri paralelných buildoch

## Prehľad problému

Pri paralelnom spúšťaní viacerých build agentov (podov) dochádza k výraznému spomaleniu:
- Git checkout: z 13 MB/s na ~100-200 KB/s
- Sťahovanie artefaktov: podobné spomalenie
- Celkové spomalenie buildov

## Identifikácia bottlenecku

### 1. Spustenie diagnostického skriptu

```bash
# Spustenie základnej diagnózy
./diagnostic-scripts/network-disk-monitor.sh

# Kontinuálne monitorovanie (každých 5 sekúnd)
watch -n 5 './diagnostic-scripts/network-disk-monitor.sh'
```

### 2. Manuálna kontrola bottlenecku

#### A) Sieťové pripojenie
```bash
# Test rýchlosti sťahovania
curl -w "Rýchlosť: %{speed_download} bytes/sec\n" -o /dev/null -s https://speed.cloudflare.com/__down?bytes=10485760

# Monitorovanie sieťových pripojení
ss -tuln | grep ESTABLISHED
netstat -i  # sieťové rozhrania a chyby
```

#### B) Disk I/O
```bash
# Inštalácia iotop ak nie je dostupný
sudo apt install iotop

# Monitorovanie disk I/O
sudo iotop -b -n 1
sudo iostat -x 1 5  # ak je dostupný sysstat

# Kontrola využitia disku
df -h
du -sh /var/lib/k3s/storage/*  # K3s storage
```

#### C) CPU a RAM
```bash
# CPU load
uptime
htop  # alebo top

# RAM využitie
free -h
cat /proc/meminfo | grep -E "(MemTotal|MemAvailable|SwapTotal|SwapFree)"
```

#### D) Kubernetes resources
```bash
# Stav podov
kubectl get pods -n build-agents -o wide

# Resource využitie (ak je metrics server)
kubectl top pods -n build-agents
kubectl top nodes

# PVC a storage
kubectl get pvc -n build-agents
kubectl describe pvc agent-cache-pvc -n build-agents
```

## Hlavné príčiny bottlenecku

### 1. **Zdieľaný PVC s local-path storage**
- **Problém**: Všetky pody používajú rovnaký PVC (`agent-cache-pvc`) s `local-path` storage class
- **Dôsledok**: Všetok disk I/O ide cez jeden lokálny disk
- **Riešenie**: Použiť separate PVC pre každý pool alebo cloud storage

### 2. **Chýbajúce resource limits**
- **Problém**: StatefulSet nemá definované CPU/RAM limity
- **Dôsledok**: Pody môžu preťažiť systém
- **Riešenie**: Pridať resource requests a limits

### 3. **Single-node cluster**
- **Problém**: Všetky pody bežia na jednom node
- **Dôsledok**: Zdieľané CPU, RAM, sieť, disk
- **Riešenie**: Multi-node cluster alebo optimalizácia single-node

## Riešenia

### Krátkodobé riešenia (okamžité)

#### 1. Obmedzenie paralelných buildov
```yaml
# V Azure DevOps pipeline
pool:
  name: 'build-be'
  demands:
  - agent.name -equals $(Agent.Name)
  # Obmedziť počet paralelných buildov na agente
```

#### 2. Shallow clone v pipeline
```yaml
steps:
- checkout: self
  fetchDepth: 1  # Len posledný commit
  clean: true
```

#### 3. Optimalizácia Git konfigurácie
```yaml
steps:
- script: |
    git config --global http.postBuffer 524288000
    git config --global http.maxRequestBuffer 100M
    git config --global core.compression 9
    git config --global pack.windowMemory 100m
    git config --global pack.packSizeLimit 100m
  displayName: 'Git optimalizácia'
```

### Strednodobé riešenia (1-2 týždne)

#### 1. Pridanie resource limits do StatefulSet
```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

#### 2. Separate PVC pre každý pool
```yaml
# V shared-resources-chart
storage:
  cache:
    size: 50Gi  # Zmenšiť z 100Gi
    storageClass: local-path
  gitCache:
    size: 20Gi
    storageClass: local-path
  artifactsCache:
    size: 30Gi
    storageClass: local-path
```

#### 3. Optimalizácia storage class
```yaml
# Použiť SSD namiesto HDD
storageClass: fast-ssd  # ak je dostupný
```

### Dlhodobé riešenia (1-2 mesiace)

#### 1. Multi-node cluster
- Pridať worker nodes do K3s clusteru
- Použiť podAntiAffinity pre rozloženie podov

#### 2. Cloud storage
- Migrovať na Azure Disk Storage
- Použiť Azure Files pre zdieľaný cache

#### 3. Git mirror/cache
- Nastaviť lokálny Git mirror
- Použiť Artifactory alebo Nexus pre artefakty

## Implementačný plán

### Fáza 1: Diagnóza (1-2 dni)
1. Spustiť diagnostický skript
2. Identifikovať hlavný bottleneck
3. Dokumentovať aktuálny stav

### Fáza 2: Krátkodobé optimalizácie (3-5 dní)
1. Pridať resource limits
2. Implementovať shallow clone
3. Optimalizovať Git konfiguráciu

### Fáza 3: Storage optimalizácia (1 týždeň)
1. Vytvoriť separate PVC pre každý pool
2. Testovať výkon s novým storage layoutom
3. Monitorovať zlepšenia

### Fáza 4: Dlhodobé riešenia (1-2 mesiace)
1. Plánovať multi-node cluster
2. Vyhodnotiť cloud storage options
3. Implementovať Git mirror

## Monitorovanie a validácia

### Kľúčové metriky
- Git checkout rýchlosť (MB/s)
- Artefakt download rýchlosť (MB/s)
- Build čas (celkový čas buildu)
- Disk I/O utilization (%)
- CPU utilization (%)
- RAM utilization (%)

### Nástroje na monitorovanie
- `kubectl top pods/nodes`
- `iotop` pre disk I/O
- `htop` pre CPU/RAM
- Azure DevOps build analytics
- Custom metrics v Kubernetes

## Príklady optimalizovaných konfigurácií

### Optimalizovaný StatefulSet
Pozri súbor `charts/build-agents-chart/templates/statefulset-optimized.yaml`

### Optimalizované values
```yaml
pool:
  replicas: 3  # Znížiť z pôvodného počtu
  minReplicas: 1
  maxReplicas: 5  # Obmedziť maximum

storage:
  cache:
    size: 30Gi
  gitCache:
    size: 10Gi
  artifactsCache:
    size: 20Gi
```

## Záver

Hlavný bottleneck je pravdepodobne zdieľaný PVC s local-path storage. Riešenie je implementovať separate storage pre každý pool a pridať resource limits. Pre najlepší výsledok zvážiť multi-node cluster alebo cloud storage. 