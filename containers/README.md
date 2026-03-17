# Containers

Questa cartella contiene i Dockerfile multi-stage per gli stack:

- angular
- go
- infra
- nest

Ogni Dockerfile espone target utili multi-stage:

- base: layer condiviso di base per lo stack
- dev: immagine usata dai Dev Container in sviluppo
- prod: immagine di runtime per deploy

Per gli stack applicativi (`angular`, `nest`, `go`), lo stage `dev` include:

- `pre-commit` per eseguire hook locali in modo uniforme
- `sonar-scanner` CLI per analisi SonarQube nei repository di applicazione

## Uso con Dev Container

Nei repository applicativi puoi usare direttamente l'immagine dev pubblicata su GHCR.

Esempio di configurazione in .devcontainer/devcontainer.json:

```json
{
	"name": "NoTIP Nest Dev",
	"image": "ghcr.io/notipswe/notip-nest-dev:v1.0.0"
}
```

Sostituisci nest con angular, go o infra in base allo stack.

Per questa repository (`notip-infra`) il devcontainer e gestito in `.devcontainer/devcontainer.json`
e punta all immagine GHCR `ghcr.io/notipswe/notip-infra-dev:<versione>`.
Il runtime Docker locale usa Docker-in-Docker (DinD) configurato nel devcontainer,
senza mount diretto di `/var/run/docker.sock` dal host.
Le operazioni locali devono passare dall interfaccia Makefile in `infra/Makefile`.

## Build e push con release-dev.sh

Lo script crea una build multi-arch e pubblica su GHCR dell'organizzazione.

Prerequisiti:

- Docker Desktop avviato
- Docker Buildx disponibile
- Login GHCR eseguito: docker login ghcr.io

Esempi:

```bash
cd containers
./release-dev.sh nest v1.2.0
```

Override opzionale org:

```bash
GHCR_ORG=altra-org ./release-dev.sh nest v1.2.0
```

Comando generale:

```bash
./release-dev.sh <stack> <versione>
```

Valori stack supportati:

- angular
- go
- infra
- nest

Tag prodotti:

```text
ghcr.io/<GHCR_ORG>/notip-<stack>-dev:<versione>
ghcr.io/<GHCR_ORG>/notip-<stack>-base:<versione>
```

Esempio reale:

```text
ghcr.io/notipswe/notip-go-dev:v1.2.0
ghcr.io/notipswe/notip-go-base:v1.2.0
```

Per lo stack infra:

```text
ghcr.io/notipswe/notip-infra-dev:v0.1.0
```

## Note rapide

- Lo script builda e pubblica sempre entrambi i target `base` e `dev` con la stessa versione
- Le piattaforme pubblicate sono linux/amd64 e linux/arm64
- GHCR_ORG ha default notipswe (override con variabile ambiente)
- Se vuoi usare una versione stabile nei Dev Container, evita tag volatili e usa tag versione espliciti
