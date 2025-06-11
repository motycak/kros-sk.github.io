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

```mermaid
graph TB
    subgraph "Azure DevOps"
        ADO[Azure DevOps<br/>Pipeline & Jobs]
        ADO_POOL[Agent Pool<br/>Čakajúce úlohy]
    end
    
    subgraph "Kubernetes Cluster (K3s - Single Node)"
        subgraph "KEDA"
            KEDA_SCALER[KEDA Scaler<br/>Monitoruje ADO Pool]
        end
        
        subgraph "StatefulSet - Build Pool"
            subgraph "Pod 1"
                AGENT1[Azure DevOps Agent<br/>Docker Container]
            end
            subgraph "Pod 2"
                AGENT2[Azure DevOps Agent<br/>Docker Container]
            end
            subgraph "Pod N"
                AGENTN[Azure DevOps Agent<br/>Docker Container]
            end
        end
        
        subgraph "Persistent Storage"
            PVC[PersistentVolumeClaim<br/>Cache Storage]
        end
        
        subgraph "Kubernetes API"
            K8S_API[Kubernetes API<br/>StatefulSet Management]
        end
    end
    
    subgraph "Helm Charts"
        HELM[Helm Charts<br/>Konfigurácia & Deployment]
    end
    
    %% Connections
    ADO --> ADO_POOL
    ADO_POOL --> KEDA_SCALER
    KEDA_SCALER --> K8S_API
    K8S_API --> StatefulSet
    HELM --> K8S_API
    
    AGENT1 --> PVC
    AGENT2 --> PVC
    AGENTN --> PVC
    
    AGENT1 --> ADO
    AGENT2 --> ADO
    AGENTN --> ADO
    
    %% Styling
    classDef azure fill:#0078d4,stroke:#005a9e,stroke-width:2px,color:#fff
    classDef keda fill:#ff6b35,stroke:#d84315,stroke-width:2px,color:#fff
    classDef k8s fill:#326ce5,stroke:#1e3a8a,stroke-width:2px,color:#fff
    classDef helm fill:#0f1689,stroke:#0f1689,stroke-width:2px,color:#fff
    classDef storage fill:#ffd700,stroke:#ff8c00,stroke-width:2px,color:#000
    
    class ADO,ADO_POOL azure
    class KEDA_SCALER keda
    class AGENT1,AGENT2,AGENTN,K8S_API k8s
    class HELM helm
    class PVC storage
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
