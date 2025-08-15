# Base image
FROM ubuntu:22.04 AS base

ENV TARGETARCH="linux-x64"
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

# KROK 1: Základné nástroje a systémové knižnice
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    tar \
    jq \
    git \
    gnupg \
    apt-transport-https \
    xauth \
    xvfb \
    libgtk2.0-0 \
    libgtk-3-0 \
    libgbm-dev \
    libnss3 \
    libxss1 \
    libasound2 \
    libxtst6 \
    && rm -rf /var/lib/apt/lists/*

# KROK 2: Google Chrome (stabilný)
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor -o /etc/apt/keyrings/google.gpg \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_BIN=/usr/bin/google-chrome

# KROK 3: Node.js LTS cez nvm + Cypress cache (root)
ENV NVM_DIR=/root/.nvm
RUN mkdir -p "$NVM_DIR" \
    && curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && source "$NVM_DIR/nvm.sh" \
    && nvm install --lts \
    && nvm alias default 'lts/*' \
    && nvm use default \
# symlinky pre dostupnosť node/npm/npx bez source-nutia
    && ln -sf "$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | tail -n 1)/bin/node" /usr/local/bin/node \
    && ln -sf "$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | tail -n 1)/bin/npm"  /usr/local/bin/npm  \
    && ln -sf "$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | tail -n 1)/bin/npx"  /usr/local/bin/npx

# PATH a Cypress cache
ENV CYPRESS_CACHE_FOLDER="/root/.cache/Cypress"

# Auto-load nvm v interaktívnom shelli
RUN echo 'export NVM_DIR="$HOME/.nvm"' >> /root/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> /root/.bashrc

# Pracovný adresár (mountneš sem repo)
WORKDIR /workspace

COPY --chmod=755 start-k8s.sh /opt/Agents/start-k8s.sh
RUN sed -i 's/\r$//' /opt/Agents/start-k8s.sh

ENTRYPOINT ["/opt/Agents/start-k8s.sh"]