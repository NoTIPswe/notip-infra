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

Required mounts:

- Docker socket: lets the runner control the host Docker daemon (Docker-outside-of-Docker)
- State directory: persists .env and generated secrets across runs

Example:

```bash
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
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
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test make up
```

Health check:

```bash
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test make health
```

Logs:

```bash
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test make logs
```

Stop stack:

```bash
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test make down
```

Reset stack (keeps CA volume):

```bash
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test make reset
```

Full reset (destroys CA volume):

```bash
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v notip_infra_state:/var/lib/notip-infra \
  local/notip-infra-prod:test make reset-all
```

## Notes

- This is not full Docker-in-Docker. It is Docker-outside-of-Docker via socket mount.
- No privileged mode is required.
- The deployment runner image orchestrates services; actual workloads still run as separate containers from compose.
