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

# Funkcia pre extrakciu čísla z hostname
get_node_id() {
    print_header "Extracting node ID from hostname..."
    local task_number=$(echo $HOSTNAME | grep -o '[0-9]*$')
    
    # Ak sa nám nepodarilo extrahovať číslo, použijeme náhodné
    if [ -z "$task_number" ]; then
        print_info "Could not extract node ID from hostname, using random number"
        task_number=$(shuf -i 1-999 -n 1)
    fi
    
    # Formátujeme na dvojciferné číslo
    printf '%02d' $task_number
}

# Funkcia na nahradenie ${NODE_ID} v premennej
replace_node_id() {
    local var_name=$1
    local var_value="${!var_name}"
    if [[ "$var_value" == *"\${NODE_ID}"* ]]; then
        local node_id=$(get_node_id)
        export "$var_name"=$(echo "$var_value" | sed "s/\${NODE_ID}/$node_id/g")
        print_info "Updated $var_name: ${!var_name}"
    fi
}

# Nahradíme ${NODE_ID} v AZP_AGENT_NAME
node_id=$(get_node_id)
print_info "Using node ID: $node_id"
replace_node_id "AZP_AGENT_NAME"

# Nastavíme KUBECONFIG na základe AZP_AGENT_NAME
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