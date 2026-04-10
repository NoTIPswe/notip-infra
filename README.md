# NoTIP Infrastructure

The infrastructure repository for the NoTIP platform. It owns the Docker Compose stack that runs every service locally or in a shared environment, plus the base container images used by all application repositories.

## Repository layout

| Folder              | Contents                                                                       |
| ------------------- | ------------------------------------------------------------------------------ |
| `infra/compose/`    | `docker-compose.yml` and overrides for the full platform stack                 |
| `infra/nats/`       | NATS JetStream configuration and mTLS certificates                             |
| `infra/keycloak/`   | Realm export and Keycloak bootstrap configuration                              |
| `infra/nginx/`      | Reverse-proxy routing rules (API gateway)                                      |
| `infra/monitoring/` | Prometheus scrape config and Grafana dashboard provisioning                    |
| `infra/secrets/`    | Docker secrets templates (never commit real values)                            |
| `infra/scripts/`    | Helper scripts (`bootstrap.sh`, `healthcheck.sh`, `keycloak-import.sh`)        |
| `containers/`       | Multi-stage Dockerfiles for each tech stack (`angular`, `go`, `nest`, `infra`) |
| `api-contracts/`    | Shared OpenAPI / AsyncAPI specs and the crypto contract                        |

## Services in the stack

The Compose stack starts the following services in dependency order:

1. **NATS JetStream** — mTLS message broker used by all backend services
2. **PostgreSQL** — relational store for the Management API
3. **TimescaleDB** — time-series store for encrypted telemetry
4. **Keycloak** — identity provider (OIDC/JWT)
5. **Management API** — tenant/gateway control plane (NestJS)
6. **Data API** — encrypted telemetry query and SSE streaming (NestJS)
7. **Data Consumer** — NATS → TimescaleDB persister + gateway liveness monitor (Go)
8. **Provisioning Service** — gateway onboarding: TLS cert + AES key issuance (NestJS)
9. **Frontend** — Angular web application
10. **Nginx** — reverse proxy routing `/api/*` to backend services
11. **Simulator** — IoT gateway simulator, started with the `simulator` profile (Go)

## First-time setup

All commands must be run from inside the `infra/` directory.

**1. Generate secrets and create `.env`:**

```bash
make bootstrap
```

This copies `.env.example` → `.env` and generates random values for all secrets (DB passwords, Keycloak client secrets, encryption key). After it finishes, open `.env` and fill in any remaining non-secret values if needed.

**2. Start the full stack with database migrations:**

```bash
make up-with-migrations
```

This pulls all service images, starts every container, and runs TypeORM migrations for both the Management API and the Data API.

**3. Verify everything is healthy:**

```bash
make health
```

## Day-to-day commands

```bash
make up                    # start all services (pull latest images first)
make down                  # stop and remove containers (volumes preserved)
make logs                  # tail all service logs
make logs-svc SVC=data-api # tail logs for a specific service
make ps                    # list running containers and their status
```

## Developing with local builds

Build a service image from source and substitute it into the stack:

```bash
# Single service
make up-local LOCAL=management-api

# Multiple services (comma-separated)
make up-local LOCAL=management-api,data-api

# Accepted values: management-api, data-api, data-consumer,
#                  provisioning-service, frontend, simulator, sim-cli
```

The Makefile builds a local Docker image tagged `:<service>:local` from the sibling repository directory and starts the whole stack with that image substituted in.

## Resetting the environment

```bash
# Bring the stack down and wipe all volumes EXCEPT the CA certificate volume
# (provisioned gateway certificates are preserved)
make reset

# Destroy EVERYTHING including the CA volume
# ⚠ This invalidates ALL previously provisioned gateway certificates
make reset-all
```

## Simulator CLI

The `sim-cli` lets you manage the simulated gateway fleet interactively. The stack must already be running before using it.

Open an interactive shell session:

```bash
cd infra
docker compose --project-directory . -f compose/docker-compose.yml run --rm sim-cli shell
```

Inside the shell you can use all subcommands without the `docker compose run` prefix:

```
# Gateways
gateways list
gateways create --factory-id FAC-001 --factory-key KEY-001 --model GW-X --firmware 1.0.0 --freq 1000
gateways bulk --count 5 --factory-id FAC-001 --factory-key KEY-001 --model GW-X --firmware 1.0.0 --freq 1000
gateways delete <gateway-uuid>

# Sensors
sensors add <gateway-id-or-uuid> --type temperature --min 20.0 --max 80.0 --algorithm uniform_random

# Anomalies
anomalies disconnect <gateway-uuid> --duration 10
```

Or run a single command non-interactively:

```bash
docker compose --project-directory . -f compose/docker-compose.yml run --rm -it sim-cli gateways list
```

## Database migrations

```bash
make migration-run-all       # run pending migrations for all services
make migration-revert-all    # revert the last migration for all services

make migration-run-management    # Management API only
make migration-run-data          # Data API only
```

## Monitoring stack

```bash
make up-monitoring           # start Prometheus + Grafana
make down-monitoring         # stop monitoring services
```

## Container images

The `containers/` folder provides multi-stage Dockerfiles for four stacks:

| Stack     | Use case                                       |
| --------- | ---------------------------------------------- |
| `angular` | Frontend builds and devcontainer               |
| `nest`    | NestJS service builds and devcontainer         |
| `go`      | Go service builds and devcontainer             |
| `infra`   | Infrastructure devcontainer (Docker-in-Docker) |

Each Dockerfile exposes three targets: `base` (shared runtime), `dev` (base + `pre-commit` and `sonar-scanner`), and `prod` (minimal runtime for deployment).

### Publishing images

```bash
cd containers
./release-dev.sh <stack> <version>
# e.g.: ./release-dev.sh nest v1.2.0
```

Override the GHCR organisation with `GHCR_ORG=my-org`. Both `linux/amd64` and `linux/arm64` are built and pushed.
