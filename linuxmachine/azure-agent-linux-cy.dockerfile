# Base image
FROM ubuntu:22.04 AS base

ENV TARGETARCH="linux-x64"
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

# ---------- KROK 1: Základ + knižnice pre Chrome/Cypress ----------
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
    # Chrome runtime knižnice
    libgtk2.0-0 \
    libgtk-3-0 \
    libgbm1 \
    libnss3 \
    libxss1 \
    libasound2 \
    libxtst6 \
    libxrandr2 \
    libxcomposite1 \
    libxcursor1 \
    libxi6 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxdamage1 \
    libxfixes3 \
    libxshmfence1 \
    libxcb-dri3-0 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    fonts-liberation \
    fonts-dejavu \
    libu2f-udev \
    # Locale/TZ
    locales tzdata \
    && rm -rf /var/lib/apt/lists/*

# Locale a časová zóna (deterministické testy)
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV TZ=Etc/UTC

# ---------- KROK 2: Google Chrome (stable) ----------
RUN mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
     | gpg --dearmor -o /etc/apt/keyrings/google.gpg \
  && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
     > /etc/apt/sources.list.d/google-chrome.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends google-chrome-stable \
  && rm -rf /var/lib/apt/lists/*

ENV CHROME_BIN=/usr/bin/google-chrome

# ---------- KROK 3: Node.js LTS cez nvm + symlinky ----------
ENV NVM_DIR=/root/.nvm
RUN mkdir -p "$NVM_DIR" \
  && curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
  && source "$NVM_DIR/nvm.sh" \
  && nvm install --lts \
  && nvm alias default 'lts/*' \
  && nvm use default \
  && ln -sf "$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | tail -n 1)/bin/node" /usr/local/bin/node \
  && ln -sf "$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | tail -n 1)/bin/npm"  /usr/local/bin/npm  \
  && ln -sf "$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | tail -n 1)/bin/npx"  /usr/local/bin/npx

# Auto-load nvm v interaktívnom shelli
RUN echo 'export NVM_DIR="$HOME/.nvm"' >> /root/.bashrc \
 && echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> /root/.bashrc

# ---------- KROK 4: Cypress cache + voliteľná predinštalácia binárky ----------
ENV CYPRESS_CACHE_FOLDER="/root/.cache/Cypress"

# Nastav verziu pri builde ak chceš pred-kešovať binárku (inak preskočí)
ARG CYPRESS_VERSION=
RUN if [ -n "$CYPRESS_VERSION" ]; then \
      npm install -g "cypress@${CYPRESS_VERSION}" && \
      cypress install --cache-folder "$CYPRESS_CACHE_FOLDER" && \
      cypress verify  --cache-folder "$CYPRESS_CACHE_FOLDER" ; \
    else \
      echo "Skipping global Cypress install; will install per-project." ; \
    fi

# (Voliteľné) Chrome flagy pre kontajnerové prostredie
# --disable-dev-shm-usage: rieši /dev/shm; --no-sandbox: ak bežíš ako root
ENV CHROME_FLAGS="--disable-dev-shm-usage --no-sandbox"

# ---------- KROK 5: Pracovný adresár a štart skript ----------
WORKDIR /workspace

COPY --chmod=755 start-k8s.sh /opt/Agents/start-k8s.sh
RUN sed -i 's/\r$//' /opt/Agents/start-k8s.sh

ENTRYPOINT ["/opt/Agents/start-k8s.sh"]