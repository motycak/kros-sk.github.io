#!/bin/bash
set -e

# Načítanie tokenu zo secretu
export AZP_TOKEN=$(cat /run/secrets/azure_pat_token)

# Nastavenie locale
export LANG="sk_SK.UTF-8"
export LC_ALL="sk_SK.UTF-8"

if [ -z "$AZP_URL" ] || [ -z "$AZP_TOKEN" ] || [ -z "$AZP_AGENT_NAME" ] || [ -z "$AZP_POOL" ]; then
  echo 1>&2 "You must set AZP_URL, AZP_TOKEN (secret) and AZP_AGENT_NAME and AZP_POOL!"
  exit 1
fi

# Vytvorenie workdir pre agenta
WORKDIR="/opt/Agents/${AZP_AGENT_NAME}"
mkdir -p ${WORKDIR}
cd ${WORKDIR}

export AGENT_ALLOW_RUNASROOT=1

print_header() {
  lightcyan="\033[1;36m"
  nocolor="\033[0m"
  echo -e "\n${lightcyan}$1${nocolor}\n"
}

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