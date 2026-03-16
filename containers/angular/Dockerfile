# Multi-stage Dockerfile: Angular

# Base
FROM node:24.14-trixie-slim AS base

LABEL org.opencontainers.image.source="https://github.com/NoTIPswe/notip-infra/" \
      org.opencontainers.image.description="Angular SPA" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app
RUN chown -R node:node /app

# Dev
FROM base AS dev

RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

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