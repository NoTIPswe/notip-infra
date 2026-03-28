FROM debian:trixie-slim AS base

# Expose contract metadata for downstream auditability.
LABEL org.opencontainers.image.source="https://github.com/NoTIPswe/notip-infra" \
    org.opencontainers.image.description="NoTIP Docs-as-Code DevContainer image" \
    org.opencontainers.image.licenses="MIT"


FROM base AS dev

ARG DEBIAN_FRONTEND=noninteractive
ARG TYPST_VERSION=0.14.2
ARG TYPST_SHA256=
ARG TYPSTYLE_VERSION=0.14.4
ARG TYPSTYLE_SHA256=

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 PYTHONUTF8=1

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    xz-utils \
    python3 \
    python3-pip \
    python3-venv \
    git \
    hunspell \
    hunspell-en-us \
    hunspell-it \
    graphviz \
    plantuml \
    default-jre-headless \
    fonts-noto \
    fonts-noto-core \
    fonts-noto-mono \
    fonts-noto-extra \
  && if ! command -v pip >/dev/null 2>&1; then ln -s /usr/bin/pip3 /usr/local/bin/pip; fi \
  && rm -rf /var/lib/apt/lists/*

# Install Typst from official release artifacts.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "${arch}" in \
      amd64) typst_arch="x86_64-unknown-linux-musl" ;; \
      arm64) typst_arch="aarch64-unknown-linux-musl" ;; \
      *) echo "Unsupported architecture: ${arch}" >&2; exit 1 ;; \
    esac; \
    typst_url="https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-${typst_arch}.tar.xz"; \
    curl -fsSL "${typst_url}" -o /tmp/typst.tar.xz; \
    if [ -n "${TYPST_SHA256}" ]; then \
      echo "${TYPST_SHA256}  /tmp/typst.tar.xz" | sha256sum -c -; \
    fi; \
    tar -xJf /tmp/typst.tar.xz -C /tmp; \
    install -m 0755 \
      "/tmp/typst-${typst_arch}/typst" \
      /usr/local/bin/typst; \
    rm -rf /tmp/typst.tar.xz "/tmp/typst-${typst_arch}"

# Install typstyle from official release artifacts.
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "${arch}" in \
      amd64) typstyle_arch="x86_64-unknown-linux-musl" ;; \
      arm64) typstyle_arch="aarch64-unknown-linux-gnu" ;; \
      *) echo "Unsupported architecture: ${arch}" >&2; exit 1 ;; \
    esac; \
    typstyle_url="https://github.com/typstyle-rs/typstyle/releases/download/v${TYPSTYLE_VERSION}/typstyle-${typstyle_arch}"; \
    curl -fsSL "${typstyle_url}" -o /tmp/typstyle; \
    if [ -n "${TYPSTYLE_SHA256}" ]; then \
      echo "${TYPSTYLE_SHA256}  /tmp/typstyle" | sha256sum -c -; \
    fi; \
    install -m 0755 /tmp/typstyle /usr/local/bin/typstyle; \
    rm -f /tmp/typstyle

COPY smoke-check.sh /usr/local/bin/smoke-check
RUN chmod +x /usr/local/bin/smoke-check

RUN /usr/local/bin/smoke-check

RUN useradd -m -u 1000 -s /bin/bash dev
