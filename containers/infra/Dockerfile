# Multi-stage Dockerfile: Infra
#
# Purpose:
# - Provide a reproducible infra-focused dev environment.
# - Keep runtime/base layers minimal and move developer tooling into the dev stage.
# - Produce a deploy-runner image that embeds infra assets and executes Makefile targets.

# Base
FROM debian:trixie-slim AS base

LABEL org.opencontainers.image.source="https://github.com/NoTIPswe/notip-infra/" \
  org.opencontainers.image.description="Infrastructure devcontainer" \
  org.opencontainers.image.licenses="MIT"

# Base system packages and shared runtime tooling.
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

# Dev
FROM base AS dev

# Dev-only CLI tooling.
# pre-commit manages hook-specific tools in isolated environments.
RUN apt-get update && apt-get install -y --no-install-recommends \
  openssh-client git pre-commit \
  && rm -rf /var/lib/apt/lists/*

# Use a non-root default user in dev stage.
# Why: aligns container behavior with typical host developer permissions.
RUN useradd -m -u 1000 -s /bin/bash dev
USER dev
