#!/bin/bash
set -e

# Načítanie tokenu zo secretu
export AZP_TOKEN=$(cat /run/secrets/azure_pat_token)

if [ -z "$AZP_URL" ] || [ -z "$AZP_TOKEN" ] || [ -z "$AZP_AGENT_NAME" ]; then
  echo 1>&2 "Musíš nastaviť AZP_URL, AZP_TOKEN (secret) a AZP_AGENT_NAME!"
  exit 1
fi

# Vytvorenie workdir pre agenta
WORKDIR="/opt/Agents/${AZP_AGENT_NAME}"
mkdir -p ${WORKDIR}
cd ${WORKDIR}

export AGENT_ALLOW_RUNASROOT=1

# Stiahnutie a rozbalenie agenta ak ešte neexistuje
if [ ! -f "./config.sh" ]; then
    curl -LsS https://vstsagentpackage.azureedge.net/agent/3.236.1/vsts-agent-linux-x64-3.236.1.tar.gz | tar -xz
fi

./config.sh --unattended \
  --url "$AZP_URL" \
  --auth pat \
  --token "$AZP_TOKEN" \
  --pool "${AZP_POOL:-Default}" \
  --agent "$AZP_AGENT_NAME" \
  --work "${WORKDIR}/_work" \
  --replace \
  --acceptTeeEula

cleanup() {
  echo "Odstraňujem agenta..."
  ./config.sh remove --unattended --auth pat --token "$AZP_TOKEN"
}

trap 'cleanup; exit 130' INT TERM

./run.sh 