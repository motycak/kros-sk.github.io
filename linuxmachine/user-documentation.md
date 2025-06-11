# Používateľská dokumentácia - Linux Build Machine

## Prehľad systému

Build agenti sú rozbehaní v kubernetes clusteri s jedným node-om. Každý pool je reprezentovaný ako StatefulSet, ktorý obsahuje určený minimálny a maximálny počet replikácií. Každá replikácia je jeden pod s Linuxovým Docker kontajnerom, v ktorom beží jeden Azure DevOps agent. Systém využíva KEDA (Kubernetes Event-driven Autoscaling) na automatické škálovanie počtu agentov v závislosti od počtu čakajúcich úloh v Azure DevOps pooloch.

## Princípy fungovania

### 1. Automatické škálovanie cez KEDA

Systém využíva KEDA scaler na automatické škálovanie počtu build agentov. Proces funguje nasledovne:

- **Monitorovanie**: KEDA kontinuálne monitoruje Azure DevOps pool a počet čakajúcich úloh
- **Škálovanie nahor**: Ak sú v poole čakajúce úlohy, KEDA vytvorí nový pod (replikáciu) v StatefulSet
- **Škálovanie nadol**: Po určitom cooldown období a ak nie sú čakajúce úlohy, KEDA znižuje počet podov
- **Limity**: Škálovanie je obmedzené na minimálny a maximálny počet replikácií definovaný pre každý pool

### 2. StatefulSet architektúra

Každý pool je implementovaný ako StatefulSet s nasledujúcimi vlastnosťami:

- **Stabilné identity**: Každý pod má stabilné meno (napr. `build-be-1`, `build-be-2`) a negeneruje náhodné čísla pre pody. číslovanie je od 1
- **Persistentné úložisko**: Cez PersistentVolumeClaim je vytvorené zdieľané úložisko medzi agentmi. Využíva sa na cache. Ak sa aj pody rušia, tak cache sa nezmaže.

### 3. Kontajnerizácia

Všetci agenti bežia v Docker kontajneroch, čo zabezpečuje:

- Konzistentné prostredie pre všetkých agentov
- Izolácia od ostatných agentov
- Jednoduchá aktualizácia a správa

### 4. Centralizovaná správa

Na mašine sa využívajú Helm charts pre centralizovanú správu konfigurácie a nasadenia poolov do kubernetesu.

## Architektúra systému

```plantuml
@startuml
!define AZURE_COLOR #0078d4
!define KEDA_COLOR #ff6b35
!define K8S_COLOR #326ce5
!define HELM_COLOR #0f1689
!define STORAGE_COLOR #ffd700

skinparam component {
    BackgroundColor<<Azure>> AZURE_COLOR
    BackgroundColor<<KEDA>> KEDA_COLOR
    BackgroundColor<<K8S>> K8S_COLOR
    BackgroundColor<<Helm>> HELM_COLOR
    BackgroundColor<<Storage>> STORAGE_COLOR
    FontColor<<Azure>> white
    FontColor<<KEDA>> white
    FontColor<<K8S>> white
    FontColor<<Helm>> white
    FontColor<<Storage>> black
}

package "Azure DevOps" <<Azure>> {
    [Azure DevOps Pipeline & Jobs] as ADO
    [Agent Pool\nČakajúce úlohy] as ADO_POOL
}

package "K3s - Single Node Cluster" {
    package "KEDA (Kubernetes Event-driven Autoscaling)" <<KEDA>> {
        [KEDA Scaler\nMonitoruje ADO Pool] as KEDA_SCALER
    }
    
    package "Kubernetes API" <<K8S>> {
        [StatefulSet Controller] as K8S_API
    }
    
    package "StatefulSet - Build Pool" <<K8S>> {
        package "Pod 1" {
            [Azure DevOps Agent\nDocker Container] as AGENT1
        }
        package "Pod 2" {
            [Azure DevOps Agent\nDocker Container] as AGENT2
        }
        package "Pod N" {
            [Azure DevOps Agent\nDocker Container] as AGENTN
        }
    }
    
    package "Persistent Storage" <<Storage>> {
        [PersistentVolumeClaim\nagent-cache-pvc\n100Gi Local Storage] as PVC
    }
    
    package "Kubernetes Resources" <<K8S>> {
        [ConfigMap\nbuild-agent-config] as CONFIG
        [Secret\nazure-pat-token] as SECRET
        [Service\nHeadless Service] as SERVICE
    }
}

package "Helm Charts" <<Helm>> {
    [Helm Chart\nbuild-agents-chart] as HELM
}

' Connections
ADO --> ADO_POOL
ADO_POOL --> KEDA_SCALER : monitoruje čakajúce úlohy
KEDA_SCALER --> K8S_API : škáluje StatefulSet
HELM --> K8S_API : nasadí konfiguráciu

K8S_API --> AGENT1 : vytvára/ruší pod
K8S_API --> AGENT2 : vytvára/ruší pod
K8S_API --> AGENTN : vytvára/ruší pod

AGENT1 --> PVC : mountuje cache
AGENT2 --> PVC : mountuje cache
AGENTN --> PVC : mountuje cache

AGENT1 --> CONFIG : číta konfiguráciu
AGENT2 --> CONFIG : číta konfiguráciu
AGENTN --> CONFIG : číta konfiguráciu

AGENT1 --> SECRET : číta PAT token
AGENT2 --> SECRET : číta PAT token
AGENTN --> SECRET : číta PAT token

AGENT1 --> ADO : spracováva úlohy
AGENT2 --> ADO : spracováva úlohy
AGENTN --> ADO : spracováva úlohy

SERVICE --> AGENT1 : service discovery
SERVICE --> AGENT2 : service discovery
SERVICE --> AGENTN : service discovery

note right of PVC
  ReadWriteOnce access mode
  Viaceré pody môžu pristupovať
  k rovnakému úložisku na jednom node
end note

note right of KEDA_SCALER
  Polling Interval: 30s
  Cooldown Period: 300s
  Min/Max Replicas: konfigurovateľné
end note

@enduml
```

## Proces škálovania

```mermaid
flowchart TD
    A[Azure DevOps Pipeline] --> B{Joby v poole čakajú?}
    B -->|Áno| C[KEDA Scaler - Scale Up]
    B -->|Nie| D[Žiadne akcie pre Scale Up]
    
    C --> F{Počet replikácií < max?}
    F -->|Áno| G[Zvýšenie počtu replikácií]
    F -->|Nie| H[Dosiahnutý max limit]
    
    G --> J[Vytvorenie nového Podu]
    J --> K[Naštartovanie Docker kontajneru]
    K --> L[Nový Azure Agent]
    G --> M[Začiatok merania cooldown]
    
    M --> P[KEDA Scaler - Scale Down]
    P --> Q{Cooldown obdobie uplynulo?}
    Q -->|Nie| R[Čakanie na cooldown]
    R --> Q
    Q -->|Áno| S{Žiadne čakajúce úlohy?}
    S -->|Áno| T{Počet replikácií > min?}
    T -->|Áno| U[Zníženie počtu replikácií]
    T -->|Nie| V[Zachovanie minimálneho počtu]
    S -->|Nie| W[Zachovanie aktuálneho počtu]
    
    U --> X[Odstránenie Podu]
    
    subgraph "KEDA"
        C
        F
        G
        H
        M
        P
        Q
        R
        S
        T
        U
        V
        W
    end
    
    subgraph "Azure DevOps Agent Pool"
        A
        B
        D
        L
    end
    
    subgraph "StatefulSet"
        J
        K
        X
    end
```

## Kľúčové komponenty

### Azure DevOps

- Spravuje build pipeline a úlohy
- Poskytuje pool agentov pre spracovanie úloh
- Komunikuje s agentmi cez Azure DevOps API
- Poskytuje informácie o čakajúcich úlohách pre KEDA

### Kubernetes (K3s) - Single Node Cluster

- Orchestruje Docker kontajnery
- Poskytuje API pre automatické škálovanie
- Spravuje StatefulSets a ich replikácie

### KEDA (Kubernetes Event-driven Autoscaling)

- Monitoruje Azure DevOps pool a počet čakajúcich úloh
- Automaticky škáluje StatefulSets podľa definovaných pravidiel
- Rešpektuje minimálne a maximálne limity replikácií

### StatefulSet

- Poskytuje stabilné identity pre pody
- Zabezpečuje ordinálne číslovanie (build-be-1, build-be-2, ...)

### Docker

- Kontajnerizuje build prostredie
- Zabezpečuje konzistentnosť prostredia
- Umožňuje rýchle nasadenie a aktualizácie

## Proces škálovania

### Škálovanie nahor (Scale Up)

1. **Monitorovanie**: KEDA každých 30 sekúnd (dá sa prispôsobiť) kontroluje počet čakajúcich úloh v Azure DevOps pool
2. **Vyhodnotenie**: Ak sú čakajúce úlohy a aktuálny počet replikácií je menší ako maximum
3. **Spustenie**: Kubernetes vytvorí nový pod (replikáciu) s Docker kontajnerom

### Škálovanie nadol (Scale Down)

1. **Cooldown**: Po triggernutí scale up eventu sa čaká 300 sekúnd (dá sa prispôsobiť) kým začne kontrola pre škálovanie nadol
2. **Vyhodnotenie**: Ak nie sú čakajúce úlohy a počet replikácií je väčší ako minimum
3. **Odstránenie**: KEDA zníži počet replikácií StatefulSet, t.j. odstráni pod

### Konfigurácia škálovania

Pre každý pool sú definované nasledujúce parametre:

- **minReplicas**: Minimálny počet replikácií (vždy aktívnych agentov)
- **maxReplicas**: Maximálny počet replikácií
- **pollingInterval**: Interval kontroly čakajúcich úloh (30s)
- **cooldownPeriod**: Obdobie čakania pred znížením (300s)
- **targetPipelinesQueueLength**: Cieľový počet čakajúcich úloh pre škálovanie (1)
