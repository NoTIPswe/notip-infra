# OpenAPI Contracts

## How this directory works

This directory follows a **code-first** approach. The files here are **generated automatically** by the CI pipeline of each NestJS service — they are not hand-written and will be overwritten.

### Workflow

1. **Extraction (Backend):** During build, a NestJS script generates `openapi.json` from Swagger decorators in the source code.
2. **Publication (CI push):** The service CI pushes the generated JSON into this directory (e.g. `management-api.json`).
3. **Consumption (Consumer pull):** Frontend (Angular) and consumer services (Go) run a local script to download the JSON from a specific commit SHA — pinning the exact API version they compile against.
4. **Lockfile:** The downloaded JSON is committed in the consumer repo as a lockfile.
5. **Code generation:** Consumers run `openapi-generator-cli` (TS) or `oapi-codegen` (Go) against the local JSON.

## Reference stubs

The `.yaml` files in this directory are **design-time reference stubs** written during the architecture phase. They document the intended API shape and are superseded by the generated `.json` files once service CI is set up.

| File | Status |
|------|--------|
| `management-api.yaml` | Reference stub — will be replaced by `management-api.json` from CI |
| `data-api.yaml` | Reference stub — will be replaced by `data-api.json` from CI |
| `provisioning-api.yaml` | Reference stub — will be replaced by `provisioning-api.json` from CI |

## Authoritative contracts (never auto-generated)

| File | Description |
|------|-------------|
| `../asyncapi/nats-contracts.yaml` | NATS subjects, streams, and message schemas |
| `../crypto-contract.md` | AES-256-GCM telemetry encryption specification |
