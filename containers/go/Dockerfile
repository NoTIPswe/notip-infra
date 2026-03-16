# Multi-stage Dockerfile: Go

# Base
FROM golang:1.26-trixie AS base

LABEL org.opencontainers.image.source="https://github.com/NoTIPswe/notip-infra/" \
      org.opencontainers.image.description="Go Application" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app


# Dev (devcontainer target)
FROM base AS dev

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# Live reload and debugger
RUN go install github.com/air-verse/air@v1.64.5 && \
    go install github.com/go-delve/delve/cmd/dlv@v1.26.1

# Builder (CI/CD)
FROM base AS builder

# Cache deps first
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Statically linked Linux binary
RUN CGO_ENABLED=0 GOOS=linux go build -o notip-app .


# Production
FROM debian:trixie-slim AS prod

RUN groupadd -r appuser && useradd -r -g appuser appuser
WORKDIR /app

# Required for outbound HTTPS
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=appuser:appuser --from=builder /app/notip-app .

USER appuser

# Optional if app exposes HTTP
# EXPOSE 8080
# HEALTHCHECK ...

CMD ["./notip-app"]