# Multi-stage Dockerfile: NestJS

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
# For reproducible builds, pin by digest:
# For strictly reproducible builds, replace the tag with a SHA256 digest:
#   FROM node:24-trixie-slim@sha256:<digest> AS base
FROM node:24.14-trixie-slim AS base

LABEL org.opencontainers.image.source="https://github.com/NoTIPswe/notip-infra/" \
      org.opencontainers.image.description="NestJS application" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app
RUN chown -R node:node /app


# Dev (devcontainer target)
FROM base AS dev

ARG SONAR_SCANNER_VERSION=8.0.1.6346

RUN apt-get update && apt-get install -y --no-install-recommends \
  git pre-commit openjdk-25-jre-headless \
    && rm -rf /var/lib/apt/lists/*

COPY --from=sonar_scanner /opt/sonar-scanner /opt/sonar-scanner
RUN ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner

RUN npm install -g @nestjs/cli@11.0

USER node

# Builder (CI/CD)
FROM base AS builder

USER node

# Cache deps first
COPY --chown=node:node package*.json ./
RUN npm ci

COPY --chown=node:node . .
RUN npm run build


# Production
FROM base AS prod

ENV NODE_ENV=production
USER node

COPY --chown=node:node package*.json ./
RUN npm ci --omit=dev

COPY --chown=node:node --from=builder /app/dist ./dist

EXPOSE 3000

# Requires GET /health -> 200
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

# Keep ENTRYPOINT + CMD for overridable Node args
ENTRYPOINT ["node"]
CMD ["dist/main"]