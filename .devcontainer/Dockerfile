FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Docker CLI (Docker-outside-of-Docker — socket is bind-mounted at runtime)
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg lsb-release \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
         | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
         https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
         > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
         docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Dev tools
RUN apt-get update && apt-get install -y --no-install-recommends \
      make jq curl openssl git \
    && rm -rf /var/lib/apt/lists/*

# yq
RUN curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$(dpkg --print-architecture)" \
      -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# pre-commit + yamllint
RUN pip3 install --no-cache-dir pre-commit yamllint

# shellcheck
RUN apt-get update && apt-get install -y --no-install-recommends shellcheck \
    && rm -rf /var/lib/apt/lists/*

# gitleaks
RUN GITLEAKS_VERSION=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest \
      | jq -r '.tag_name' | tr -d v) \
    && curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_$(dpkg --print-architecture).tar.gz" \
         | tar -xz -C /usr/local/bin gitleaks
