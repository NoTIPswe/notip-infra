# Multi-stage Dockerfile: Angular

ARG SONAR_SCANNER_VERSION=8.0.1.6346

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

# Base
FROM node:24.14-trixie-slim AS base

LABEL org.opencontainers.image.source="https://github.com/NoTIPswe/notip-infra/" \
      org.opencontainers.image.description="Angular SPA" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app
RUN chown -R node:node /app

# Dev
FROM base AS dev

ARG SONAR_SCANNER_VERSION=8.0.1.6346

RUN apt-get update && apt-get install -y --no-install-recommends \
  git pre-commit openjdk-25-jre-headless \
    && rm -rf /var/lib/apt/lists/*

COPY --from=sonar_scanner /opt/sonar-scanner /opt/sonar-scanner
RUN ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner

RUN npm install -g @angular/cli@21.2

USER node

# Builder
FROM base AS builder

USER node
COPY --chown=node:node package*.json ./
RUN npm ci

COPY --chown=node:node . .

RUN npm run build -- --configuration production --output-path=dist-generic


# Production
FROM nginxinc/nginx-unprivileged:1-alpine AS prod

USER root
WORKDIR /app

COPY --chown=nginx:nginx --from=builder /app/dist-generic/browser /usr/share/nginx/html

USER nginx
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

CMD ["nginx", "-g", "daemon off;"]