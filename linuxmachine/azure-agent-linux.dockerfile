FROM ubuntu:22.04 AS base

ENV TARGETARCH="linux-x64"
ENV DEBIAN_FRONTEND=noninteractive

# Install basic packages in one RUN command
RUN apt update && \
    apt upgrade -y && \
    apt install -y \
        curl \
        jq \
        libicu70 \
        zip \
        wget \
        apt-transport-https \
        software-properties-common \
        gnupg2 \
        libssl3 \
        libssl-dev \
        openssl \
        ca-certificates \
        locales \
        tzdata \
        mono-complete && \
    # Installing higher version of git (not officialy supported for ubuntu 22.04) because of troubles with dotnet affected
    add-apt-repository ppa:git-core/ppa && \
    apt update && \
    apt install -y git && \
    # Set locale
    sed -i '/sk_SK.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    # Set timezone
    echo "Europe/Bratislava" > /etc/timezone && \
    ln -sf /usr/share/zoneinfo/Europe/Bratislava /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    # Add repository for libssl1.1 (needed by .NET for Azure Functions)
    wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb && \
    dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb && \
    rm libssl1.1_1.1.1f-1ubuntu2_amd64.deb && \
    rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV LANG=sk_SK.UTF-8
ENV LANGUAGE=sk_SK:sk
ENV LC_ALL=sk_SK.UTF-8

FROM base AS dotnet-stage
ENV DOTNET_INSTALL_DIR="/usr/lib/dotnet"
ENV PATH="$PATH:/usr/lib/dotnet"
ENV DOTNET_ROOT="/usr/lib/dotnet"

# Installing .NET SDK versions
RUN curl -sSL https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh | bash -s -- --channel 3.1 && \
    curl -sSL https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh | bash -s -- --channel 5.0 && \
    curl -sSL https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh | bash -s -- --channel 6.0 && \
    curl -sSL https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh | bash -s -- --channel 7.0 && \
    curl -sSL https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh | bash -s -- --channel 8.0 && \
    curl -sSL https://builds.dotnet.microsoft.com/dotnet/scripts/v1/dotnet-install.sh | bash -s -- --channel 9.0

FROM dotnet-stage AS node-powershell-stage

# Installing Node.js (latest LTS version)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get update && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Installing PowerShell
RUN wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell && \
    ln -s /usr/bin/pwsh /usr/bin/powershell && \
    rm -rf /var/lib/apt/lists/*

FROM node-powershell-stage AS azure-stage

# Installing Azure PowerShell
RUN pwsh -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted" && \
    pwsh -Command "Install-Module -Name Az -AllowClobber -Scope AllUsers -Force"

# Installing Azure CLI and configuration
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
    az config set extension.dynamic_install_allow_preview=true && \
    az extension add --name azure-devops

FROM azure-stage AS final

# Installing kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Inštalácia Azure artifacts credential provider
RUN wget -qO- https://aka.ms/install-artifacts-credprovider.sh | bash && \
    sh -c "$(curl -fsSL https://aka.ms/install-artifacts-credprovider.sh)"

# Creating user for Azure agent
RUN useradd -m -d /home/azure-agent azure-agent

# Creating cache directories and setting environment variables
WORKDIR /opt/Agents
ENV CYPRESS_CACHE_FOLDER="/opt/Agents/cache/cypress" \
    NPM_CONFIG_CACHE="/opt/Agents/cache/npm" \
    NUGET_PACKAGES="/opt/Agents/cache/nuget" \
    NX_CACHE_FOLDER="/opt/Agents/cache/nx"

# Installing .NET global tools and Newman
RUN mkdir -p /opt/Agents/tools && \
    dotnet tool install dotnet-affected --tool-path /opt/Agents/tools && \
    dotnet tool install Kros.DummyData.Initializer --tool-path /opt/Agents/tools && \
    dotnet tool install Kros.VariableSubstitution --tool-path /opt/Agents/tools && \
    npm install -g newman

# Setting ownership of files to azure-agent user
RUN chown -R azure-agent:azure-agent /opt/Agents && \
    chown -R azure-agent:azure-agent /home/azure-agent
ENV PATH="$PATH:/opt/Agents/tools"

COPY start-k8s.sh .
RUN chmod +x start-k8s.sh && \
    chown azure-agent:azure-agent start-k8s.sh

USER azure-agent

ENTRYPOINT ["./start-k8s.sh"] 