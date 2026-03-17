# Multi-stage Dockerfile: Go

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
FROM golang:1.26-trixie AS base

LABEL org.opencontainers.image.source="https://github.com/NoTIPswe/notip-infra/" \
      org.opencontainers.image.description="Go Application" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app


# Dev (devcontainer target)
FROM base AS dev

ARG SONAR_SCANNER_VERSION=8.0.1.6346

RUN apt-get update && apt-get install -y --no-install-recommends \
    git pre-commit openjdk-25-jre-headless \
    && rm -rf /var/lib/apt/lists/*

COPY --from=sonar_scanner /opt/sonar-scanner /opt/sonar-scanner
RUN ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner

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
