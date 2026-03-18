FROM debian:trixie-slim AS base

LABEL org.opencontainers.image.source="https://github.com/NoTIPswe/notip-infra" \
  org.opencontainers.image.description="Infrastructure devcontainer" \
  org.opencontainers.image.licenses="MIT"

# TODO: check if still needed after reviewing the infrastructure and its dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg lsb-release bash \
  make jq openssl \
  && install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/debian/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  > /etc/apt/sources.list.d/docker.list \
  && apt-get update && apt-get install -y --no-install-recommends \
  docker-ce-cli docker-compose-plugin \
  && rm -rf /var/lib/apt/lists/*


# ----------------------------------------------------------


FROM base AS dev

RUN apt-get update && apt-get install -y --no-install-recommends \
  curl gh openssh-client git pre-commit \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 -s /bin/bash dev
