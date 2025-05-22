# Docker Swarm Konfigurácia pre Azure DevOps Agenty

Tento dokument popisuje riešenie pre správu Azure DevOps agentov pomocou Docker Swarm s využitím Docker Configs.

## Štruktúra riešenia

```
.
├── agent-config.json           # Konfiguračný súbor pre agenty
├── manage-agents.sh           # Skript pre správu služieb
├── start.sh                   # Skript pre spustenie agenta
└── azure-agent-linux.dockerfile # Dockerfile pre agenta
```

## 1. Konfiguračný súbor (agent-config.json)

```json
{
  "pools": {
    "build-be": {
      "name": "build-be-pool",
      "replicas": 3,
      "agent_name_template": "docker-{id}-build4",
      "resources": {
        "memory_limit": "4G",
        "memory_reservation": "2G",
        "cpu_limit": "2",
        "cpu_reservation": "1"
      }
    },
    "build-fe": {
      "name": "build-fe-pool",
      "replicas": 2,
      "agent_name_template": "docker-{id}-build4",
      "resources": {
        "memory_limit": "4G",
        "memory_reservation": "2G",
        "cpu_limit": "2",
        "cpu_reservation": "1"
      }
    },
    "deploy-fe": {
      "name": "deploy-fe-pool",
      "replicas": 1,
      "agent_name_template": "docker-{id}-build4",
      "resources": {
        "memory_limit": "4G",
        "memory_reservation": "2G",
        "cpu_limit": "2",
        "cpu_reservation": "1"
      }
    },
    "deploy-be": {
      "name": "deploy-be-pool",
      "replicas": 1,
      "agent_name_template": "docker-{id}-build4",
      "resources": {
        "memory_limit": "4G",
        "memory_reservation": "2G",
        "cpu_limit": "2",
        "cpu_reservation": "1"
      }
    },
    "default": {
      "name": "default-pool",
      "replicas": 1,
      "agent_name_template": "docker-{id}-build4",
      "resources": {
        "memory_limit": "4G",
        "memory_reservation": "2G",
        "cpu_limit": "2",
        "cpu_reservation": "1"
      }
    }
  },
  "common": {
    "azp_url": "https://dev.azure.com/krossk",
    "restart_policy": {
      "condition": "any",
      "delay": "5s",
      "max_attempts": 3,
      "window": "120s"
    },
    "volumes": {
      "cache": {
        "source": "agent-cache",
        "target": "/opt/Agents/cache",
        "type": "volume"
      }
    }
  }
}
```

## 2. Skript pre správu služieb (manage-agents.sh)

```bash
#!/bin/bash

# Načítanie configu
CONFIG_FILE="/opt/Agents/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found!"
    exit 1
fi

# Funkcia pre vytvorenie služby
create_service() {
    local pool_name=$1
    local pool_config=$(jq -r ".pools.\"$pool_name\"" "$CONFIG_FILE")
    local common_config=$(jq -r ".common" "$CONFIG_FILE")
    
    # Extrakcia hodnôt z configu
    local agent_pool=$(echo "$pool_config" | jq -r ".name")
    local replicas=$(echo "$pool_config" | jq -r ".replicas")
    local memory_limit=$(echo "$pool_config" | jq -r ".resources.memory_limit")
    local memory_reservation=$(echo "$pool_config" | jq -r ".resources.memory_reservation")
    local cpu_limit=$(echo "$pool_config" | jq -r ".resources.cpu_limit")
    local cpu_reservation=$(echo "$pool_config" | jq -r ".resources.cpu_reservation")
    local azp_url=$(echo "$common_config" | jq -r ".azp_url")
    
    # Vytvorenie služby
    docker service create \
        --name "azure-agent-$pool_name" \
        --replicas "$replicas" \
        --restart-condition any \
        --restart-delay 5s \
        --restart-max-attempts 3 \
        --restart-window 120s \
        --limit-memory "$memory_limit" \
        --reserve-memory "$memory_reservation" \
        --limit-cpu "$cpu_limit" \
        --reserve-cpu "$cpu_reservation" \
        --env AZP_URL="$azp_url" \
        --env AZP_POOL="$agent_pool" \
        --env AZP_AGENT_NAME="docker-\${NODE_ID}-build4" \
        --secret azure_pat_token \
        --mount type=volume,source=agent-cache,target=/opt/Agents/cache \
        --config source=agent-config,target=/opt/Agents/config.json \
        azure-agent-linux:latest
}

# Funkcia pre aktualizáciu služby
update_service() {
    local pool_name=$1
    local pool_config=$(jq -r ".pools.\"$pool_name\"" "$CONFIG_FILE")
    local replicas=$(echo "$pool_config" | jq -r ".replicas")
    
    docker service update \
        --replicas "$replicas" \
        "azure-agent-$pool_name"
}

# Hlavný skript
case "$1" in
    "deploy")
        # Vytvorenie configu v Swarm
        docker config create agent-config "$CONFIG_FILE"
        
        # Vytvorenie všetkých služieb
        for pool in $(jq -r '.pools | keys[]' "$CONFIG_FILE"); do
            create_service "$pool"
        done
        ;;
    "update")
        # Aktualizácia všetkých služieb
        for pool in $(jq -r '.pools | keys[]' "$CONFIG_FILE"); do
            update_service "$pool"
        done
        ;;
    "scale")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 scale <pool_name> <replicas>"
            exit 1
        fi
        docker service scale "azure-agent-$2=$3"
        ;;
    *)
        echo "Usage: $0 {deploy|update|scale}"
        exit 1
        ;;
esac
```

## 3. Skript pre spustenie agenta (start.sh)

```bash
#!/bin/bash
set -e

print_header() {
  lightcyan="\033[1;36m"
  nocolor="\033[0m"
  echo -e "\n${lightcyan}$1${nocolor}\n"
}

print_info() {
  lightgreen="\033[1;32m"
  nocolor="\033[0m"
  echo -e "${lightgreen}$1${nocolor}"
}

# Načítanie configu
CONFIG_FILE="/opt/Agents/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    print_header "Config file not found!"
    exit 1
fi

# Funkcia pre extrakciu čísla z hostname
get_node_id() {
    print_header "Extracting node ID from hostname..."
    local task_number=$(echo $HOSTNAME | grep -o '[0-9]*$')
    
    if [ -z "$task_number" ]; then
        print_info "Could not extract node ID from hostname, using random number"
        task_number=$(shuf -i 1-999 -n 1)
    fi
    
    printf '%02d' $task_number
}

# Nahradenie ${NODE_ID} v AZP_AGENT_NAME
node_id=$(get_node_id)
print_info "Using node ID: $node_id"
export AZP_AGENT_NAME=$(echo "$AZP_AGENT_NAME" | sed "s/\${NODE_ID}/$node_id/g")
print_info "Updated AZP_AGENT_NAME: $AZP_AGENT_NAME"

# Nastavenie KUBECONFIG
export KUBECONFIG="/opt/Agents/${AZP_AGENT_NAME}/kubeconfig"
print_info "Set KUBECONFIG: $KUBECONFIG"

# Načítanie tokenu zo secretu
export AZP_TOKEN=$(cat /run/secrets/azure_pat_token)

if [ -z "$AZP_URL" ] || [ -z "$AZP_TOKEN" ] || [ -z "$AZP_AGENT_NAME" ] || [ -z "$AZP_POOL" ]; then
  echo 1>&2 "You must set AZP_URL, AZP_TOKEN (secret) and AZP_AGENT_NAME and AZP_POOL!"
  exit 1
fi

# Vytvorenie workdir pre agenta
WORKDIR="/opt/Agents/${AZP_AGENT_NAME}"
mkdir -p ${WORKDIR}
cd ${WORKDIR}

export AGENT_ALLOW_RUNASROOT=1

# Let the agent ignore the token env variables
export VSO_AGENT_IGNORE="AZP_TOKEN"

# Odstránenie existujúcej konfigurácie (ak existuje)
if [ -f "./config.sh" ]; then
    print_header "Removing existing agent configuration..."
    while true; do
        ./config.sh remove --unattended --auth pat --token "$AZP_TOKEN" && break
        echo "Failed to remove agent, retrying in 30 seconds..."
        sleep 30
    done
fi

# Downloading and extracting Azure Pipelines agent
print_header "Downloading and extracting Azure Pipelines agent..."
AGENT_VERSION=$(curl -s https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | jq -r '.tag_name' | sed 's/v//')

if [ -z "$AGENT_VERSION" ] || [ "$AGENT_VERSION" == "null" ]; then
    AGENT_VERSION="4.254.0"
fi

echo "Downloading Azure Pipelines agent version $AGENT_VERSION"
curl -LsS "https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-${TARGETARCH}-${AGENT_VERSION}.tar.gz" | tar -xz

print_header "Configuring Azure Pipelines agent..."
print_header "AZP_AGENT_NAME: $AZP_AGENT_NAME"

./config.sh --unattended \
  --url "$AZP_URL" \
  --auth pat \
  --token "$AZP_TOKEN" \
  --pool "${AZP_POOL}" \
  --agent "$AZP_AGENT_NAME" \
  --work "${WORKDIR}/_work" \
  --replace \
  --acceptTeeEula

cleanup() {
  print_header "Removing agent..."
  while true; do
    ./config.sh remove --unattended --auth pat --token "$AZP_TOKEN" && break
    echo "Failed to remove agent, retrying in 30 seconds..."
    sleep 30
  done
}

trap 'cleanup; exit 130' INT TERM

print_header "Starting Azure Pipelines agent..."

./run.sh
```

## Použitie

### 1. Inicializácia Swarm clusteru

```bash
# Na manager node
docker swarm init

# Na worker nodes
docker swarm join --token <token> <manager-ip>:2377
```

### 2. Vytvorenie secretu pre PAT token

```bash
echo "your-pat-token" | docker secret create azure_pat_token -
```

### 3. Nasadenie služieb

```bash
# Nastavenie práv na skript
chmod +x manage-agents.sh

# Nasadenie všetkých služieb
./manage-agents.sh deploy

# Aktualizácia služieb podľa configu
./manage-agents.sh update

# Škálovanie konkrétneho poolu
./manage-agents.sh scale build-be 5
```

### 4. Kontrola stavu

```bash
# Zobrazenie všetkých služieb
docker service ls

# Detailné informácie o službe
docker service ps azure-agent-build-be

# Logy služby
docker service logs azure-agent-build-be
```

## Výhody riešenia

1. **Centralizovaná konfigurácia**
   - Všetky nastavenia v jednom JSON súbore
   - Jednoduchá údržba a aktualizácia
   - Možnosť versionovať konfiguráciu

2. **Flexibilné škálovanie**
   - Jednoduché pridávanie/odoberanie agentov
   - Možnosť škálovať jednotlivé pooly nezávisle
   - Automatické reštarty pri zlyhaní

3. **Správa zdrojov**
   - Definované limity pre CPU a RAM
   - Možnosť prispôsobiť pre každý pool
   - Lepšia kontrola nad využitím zdrojov

4. **Bezpečnosť**
   - PAT token uložený ako Docker secret
   - Konfigurácia dostupná len v kontajneroch
   - Izolované prostredie pre každého agenta

5. **Monitorovanie a logovanie**
   - Farebné výpisy v logoch
   - Jednoduché sledovanie stavu agentov
   - Možnosť debugovať problémy

## Údržba

### Aktualizácia configu

1. Upravte `agent-config.json`
2. Spustite `./manage-agents.sh update`

### Pridanie nového poolu

1. Pridajte novú sekciu do `agent-config.json`
2. Spustite `./manage-agents.sh deploy`

### Odstránenie poolu

```bash
docker service rm azure-agent-<pool-name>
```

### Čistenie cache

```bash
docker volume rm agent-cache
```

## Poznámky

- Všetky agenty používajú rovnaký Docker image
- Cache je zdieľaná medzi všetkými agentmi
- Každý agent má vlastný workdir
- Konfigurácia je dostupná v kontajneri na `/opt/Agents/config.json`
- PAT token je dostupný v kontajneri na `/run/secrets/azure_pat_token` 