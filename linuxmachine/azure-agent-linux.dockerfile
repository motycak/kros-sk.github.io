FROM ubuntu:22.04

ENV TARGETARCH="linux-x64"

RUN apt update && \
  apt upgrade -y && \
  apt install -y curl git jq libicu70 zip wget apt-transport-https software-properties-common gnupg2 libssl3 libssl-dev openssl ca-certificates && \
  rm -rf /var/lib/apt/lists/*

# Add repository for libssl1.1 (needed by .NET for Azure Functions)
RUN wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb && \
    dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb && \
    rm libssl1.1_1.1.1f-1ubuntu2_amd64.deb

# Installing .NET SDK versions
ENV DOTNET_INSTALL_DIR="/usr/lib/dotnet"
RUN curl -sSL https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh | bash -s -- --channel 3.1 && \
    curl -sSL https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh | bash -s -- --channel 5.0 && \
    curl -sSL https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh | bash -s -- --channel 6.0 && \
    curl -sSL https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh | bash -s -- --channel 7.0 && \
    curl -sSL https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh | bash -s -- --channel 8.0
ENV PATH="$PATH:/usr/lib/dotnet"

# Installing GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh

# Installing Node.js (latest LTS version)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs

# Installing PowerShell
RUN wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell && \
    ln -s /usr/bin/pwsh /usr/bin/powershell

# Installing Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Installing Kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Nastavenie lokalizácie a časovej zóny - neinteraktívne
RUN echo "Europe/Bratislava" > /etc/timezone && \
    ln -fs /usr/share/zoneinfo/Europe/Bratislava /etc/localtime && \
    apt-get update && \
    apt-get install -y locales tzdata && \
    locale-gen sk_SK.UTF-8 && \
    update-locale LANG=sk_SK.UTF-8 LC_ALL=sk_SK.UTF-8 && \
    dpkg-reconfigure -f noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=sk_SK.UTF-8 \
    LC_ALL=sk_SK.UTF-8 \
    TZ=Europe/Bratislava

WORKDIR /opt/Agents

# Cache folders and variables
RUN mkdir -p /opt/Agents/cache/cypress \
    /opt/Agents/cache/npm \
    /opt/Agents/cache/nuget \
    /opt/Agents/cache/nx
ENV CYPRESS_CACHE_FOLDER="/opt/Agents/cache/cypress" \
    NPM_CONFIG_CACHE="/opt/Agents/cache/npm" \
    NUGET_PACKAGES="/opt/Agents/cache/nuget" \
    NX_CACHE_FOLDER="/opt/Agents/cache/nx"

COPY start.sh .
RUN chmod +x start.sh

ENTRYPOINT ["./start.sh"]

# # 7-Zip
# RUN apt-get install -y p7zip-full