# Infra Container

This container supports two use cases:

- dev stage: developer tooling for local work
- prod stage: deployment runner that packages infra assets and executes Makefile targets

## Build Images

Build dev image (same context used by release-dev.sh):

```bash
docker build --target dev -f containers/infra/Dockerfile containers/infra -t local/notip-infra-dev:test
```

Build prod deploy-runner image:

```bash
docker build --target prod -f containers/infra/Dockerfile . -t local/notip-infra-prod:test
```

Important:

- The prod build must use repository root context (.) because the Dockerfile copies the infra directory.

## Run Deployment Container

Runtime model:

- Local development in devcontainer: use Docker-in-Docker (DinD) configured in `.devcontainer/devcontainer.json`.
- GitHub-hosted runners: use the runner host Docker daemon (no DinD service container).

Required runtime inputs:

- Docker daemon access from the current environment (DinD locally, host daemon on CI runner)
- State directory: persists .env and generated secrets across runs

Example:

```bash
docker run --rm -it \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test
```

Default command is:

```text
make up
```

## Operational Commands

Start stack:

```bash
docker run --rm -it \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test make up
```

Health check:

```bash
docker run --rm -it \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test make health
```

Logs:

```bash
docker run --rm -it \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test make logs
```

Stop stack:

```bash
docker run --rm -it \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test make down
```

Reset stack (keeps CA volume):

```bash
docker run --rm -it \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test make reset
```

Full reset (destroys CA volume):

```bash
docker run --rm -it \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test make reset-all
```

## Notes

- The deployment runner requires access to a Docker daemon. In local devcontainer this is DinD. In GitHub-hosted runners this is the runner host daemon.
- If Docker commands fail, check `docker info` before invoking Makefile targets.
- The deployment runner image orchestrates services; actual workloads still run as separate containers from compose.
