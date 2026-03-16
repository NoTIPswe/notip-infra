# Multi-stage Dockerfile: NestJS

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

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

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