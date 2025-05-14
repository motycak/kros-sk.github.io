FROM ubuntu:22.04

ENV TARGETARCH="linux-x64"

RUN apt update && \
  apt upgrade -y && \
  apt install -y curl git jq libicu70 zip wget apt-transport-https software-properties-common gnupg2 && \
  rm -rf /var/lib/apt/lists/*

# Installing .NET SDK versions
RUN apt-get update && \
    apt-get install -y dotnet-sdk-6.0 dotnet-sdk-7.0 dotnet-sdk-8.0 && \
    rm -rf /var/lib/apt/lists/*

# Installing older versions of .NET SDK
ENV DOTNET_INSTALL_DIR="/usr/lib/dotnet"
RUN curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --version 3.1.426 && \
    curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --version 5.0.408

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

# Základné nástroje
# RUN apt-get update && apt-get install -y \
#     curl \
#     wget \
#     git \
#     unzip \
#     ca-certificates \
#     apt-transport-https \
#     software-properties-common \
#     sudo \
#     jq \
#     lsb-release \
#     gnupg2

# # .NET SDK 7 a 8
# RUN wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
#     dpkg -i packages-microsoft-prod.deb && \
#     rm packages-microsoft-prod.deb && \
#     apt-get update && \
#     apt-get install -y dotnet-sdk-7.0 dotnet-sdk-8.0

# # kubectl
# RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
#     chmod +x kubectl && mv kubectl /usr/local/bin/

# # GitHub CLI
# RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
#     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
#     apt-get update && \
#     apt-get install -y gh

# # 7-Zip
# RUN apt-get install -y p7zip-full