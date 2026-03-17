# Multi-stage Dockerfile: Angular

ARG SONAR_SCANNER_VERSION=8.0.1.6346


# Base
FROM node:24.14-trixie-slim AS base

LABEL org.opencontainers.image.source="https://github.com/NoTIPswe/notip-infra/" \
  org.opencontainers.image.description="Angular SPA" \
  org.opencontainers.image.licenses="MIT"

WORKDIR /app
RUN chown -R node:node /app


# Sonar scanner helper stage
FROM debian:trixie-slim AS sonar_scanner
ARG SONAR_SCANNER_VERSION=8.0.1.6346

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates curl unzip \
  && rm -rf /var/lib/apt/lists/* \
  && curl -fsSL "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}.zip" \
  -o /tmp/sonar-scanner.zip \
  && unzip -q /tmp/sonar-scanner.zip -d /opt \
  && mv "/opt/sonar-scanner-${SONAR_SCANNER_VERSION}" /opt/sonar-scanner \
  && rm -f /tmp/sonar-scanner.zip


# Dev
FROM base AS dev

ARG SONAR_SCANNER_VERSION=8.0.1.6346

RUN apt-get update && apt-get install -y --no-install-recommends \
  openssh-client git pre-commit openjdk-25-jre-headless \
  && rm -rf /var/lib/apt/lists/*

COPY --from=sonar_scanner /opt/sonar-scanner /opt/sonar-scanner
RUN ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner

RUN npm install -g @angular/cli@21.2

USER node
