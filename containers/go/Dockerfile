FROM golang:1.26-trixie AS base

LABEL org.opencontainers.image.source="https://github.com/NoTIPswe/notip-infra" \
    org.opencontainers.image.description="Go Application" \
    org.opencontainers.image.licenses="MIT"


# ----------------------------------------------------------


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


# ----------------------------------------------------------


FROM base AS dev

ARG SONAR_SCANNER_VERSION=8.0.1.6346

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gh openssh-client git pre-commit openjdk-25-jre-headless \
    && rm -rf /var/lib/apt/lists/*

ARG TARGETARCH
ENV JAVA_HOME=/usr/lib/jvm/java-25-openjdk-${TARGETARCH}

COPY --from=sonar_scanner /opt/sonar-scanner /opt/sonar-scanner
RUN ln -s /opt/sonar-scanner/bin/sonar-scanner /usr/local/bin/sonar-scanner

RUN go install github.com/air-verse/air@v1.64.5 && \
    go install github.com/go-delve/delve/cmd/dlv@v1.26.1 && \
    go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.11.3

RUN useradd -m -u 1000 -s /bin/bash dev
USER dev
