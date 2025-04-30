FROM ubuntu:22.04

ENV TARGETARCH="linux-x64"

RUN apt update && \
  apt upgrade -y && \
  apt install -y curl git jq libicu70

RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

RUN mkdir -p /opt/Agents

COPY start.sh /opt/Agents/
RUN chmod +x /opt/Agents/start.sh

WORKDIR /opt/Agents
ENTRYPOINT ["./start.sh"]

# ENV DEBIAN_FRONTEND=noninteractive

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

# # Node.js LTS
# RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
#     apt-get install -y nodejs

# # Azure CLI
# RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

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