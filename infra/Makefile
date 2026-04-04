COMPOSE_FILE := compose/docker-compose.yml
COMPOSE_MONITORING := compose/docker-compose.monitoring.yml
COMPOSE_CMD := docker compose --project-directory . -f ${COMPOSE_FILE}

.PHONY: bootstrap up up-with-migrations up-monitoring down reset reset-all logs ps keycloak-import health lint \
	migration-run migration-revert migration-run-management migration-revert-management \
	migration-run-data migration-revert-data migration-run-all migration-revert-all

bootstrap:
	@bash scripts/bootstrap.sh

up:
	@set -eu; \
	LOCAL_SERVICES="$${LOCAL:-$${local:-}}"; \
	COMPOSE_ENV=""; \
	LOCAL_IMAGES=""; \
	SKIP_PULL=0; \
	if [ -n "$$LOCAL_SERVICES" ]; then \
	  SKIP_PULL=1; \
	  OLD_IFS="$$IFS"; IFS=','; set -- $$LOCAL_SERVICES; IFS="$$OLD_IFS"; \
	  for raw in "$$@"; do \
	    svc=$$(printf '%s' "$$raw" | tr -d '[:space:]'); \
	    case "$$svc" in \
	      management|management-api|mgmt) \
	        COMPOSE_ENV="$$COMPOSE_ENV MGMT_API_IMAGE=notip-management-api:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-management-api:local" ;; \
	      data-api|data) \
	        COMPOSE_ENV="$$COMPOSE_ENV DATA_API_IMAGE=notip-data-api:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-data-api:local" ;; \
	      data-consumer|consumer) \
	        COMPOSE_ENV="$$COMPOSE_ENV DATA_CONSUMER_IMAGE=notip-data-consumer:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-data-consumer:local" ;; \
	      provisioning|provisioning-service) \
	        COMPOSE_ENV="$$COMPOSE_ENV PROVISIONING_IMAGE=notip-provisioning-service:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-provisioning-service:local" ;; \
	      frontend|notip-frontend) \
	        COMPOSE_ENV="$$COMPOSE_ENV FRONTEND_IMAGE=notip-frontend:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-frontend:local" ;; \
	      simulator|simulator-backend|notip-simulator-backend) \
	        COMPOSE_ENV="$$COMPOSE_ENV SIMULATOR_IMAGE=notip-simulator-backend:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-simulator-backend:local" ;; \
	      sim-cli|cli) \
	        COMPOSE_ENV="$$COMPOSE_ENV SIM_CLI_IMAGE=notip-simulator-cli:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-simulator-cli:local" ;; \
	      '') ;; \
	      *) \
	        echo "Unknown local service '$$svc'."; \
	        echo "Valid values: management-api,data-api,data-consumer,provisioning-service,frontend,simulator,sim-cli"; \
	        exit 1 ;; \
	    esac; \
	  done; \
	  for image in $$LOCAL_IMAGES; do \
	    echo "Building local image '$$image'..."; \
	    case "$$image" in \
	      notip-management-api:local) docker build --target prod -t "$$image" ../../notip-management-api ;; \
	      notip-data-api:local) docker build --target prod -t "$$image" ../../notip-data-api ;; \
	      notip-data-consumer:local) docker build --target prod -t "$$image" ../../notip-data-consumer ;; \
	      notip-provisioning-service:local) docker build --target prod -t "$$image" ../../notip-provisioning-service ;; \
	      notip-frontend:local) docker build --target prod -t "$$image" ../../notip-frontend ;; \
	      notip-simulator-backend:local) docker build --target prod -t "$$image" ../../notip-simulator-backend ;; \
	      notip-simulator-cli:local) docker build --target prod -t "$$image" ../../notip-simulator-cli ;; \
	      *) echo "No build rule configured for local image '$$image'."; exit 1 ;; \
	    esac; \
	  done; \
	  echo "Using local images for: $$LOCAL_SERVICES"; \
	fi; \
	if [ "$$SKIP_PULL" -eq 0 ]; then \
	  $(COMPOSE_CMD) pull; \
	else \
	  echo "Skipping explicit pull because local image tags are selected."; \
	fi; \
	eval "$$COMPOSE_ENV $(COMPOSE_CMD) up -d"

up-monitoring:
	docker compose -f $(COMPOSE_MONITORING) up -d

up-with-migrations:
	@$(MAKE) up LOCAL="$(or $(LOCAL),$(local))"
	@$(MAKE) migration-run-all

down:
	$(COMPOSE_CMD) down

# Bring stack down and remove all named volumes EXCEPT notip_ca_certs
# Preserves provisioned gateway certificates.
reset:
	$(COMPOSE_CMD) down
	@docker volume ls --format '{{.Name}}' \
	  | grep '^notip_' \
	  | grep -v 'notip_ca_certs' \
	  | xargs -r docker volume rm
	@set -eu; \
	LOCAL_SERVICES="$${LOCAL:-$${local:-}}"; \
	COMPOSE_ENV=""; \
	LOCAL_IMAGES=""; \
	SKIP_PULL=0; \
	if [ -n "$$LOCAL_SERVICES" ]; then \
	  SKIP_PULL=1; \
	  OLD_IFS="$$IFS"; IFS=','; set -- $$LOCAL_SERVICES; IFS="$$OLD_IFS"; \
	  for raw in "$$@"; do \
	    svc=$$(printf '%s' "$$raw" | tr -d '[:space:]'); \
	    case "$$svc" in \
	      management|management-api|mgmt) \
	        COMPOSE_ENV="$$COMPOSE_ENV MGMT_API_IMAGE=notip-management-api:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-management-api:local" ;; \
	      data-api|data) \
	        COMPOSE_ENV="$$COMPOSE_ENV DATA_API_IMAGE=notip-data-api:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-data-api:local" ;; \
	      data-consumer|consumer) \
	        COMPOSE_ENV="$$COMPOSE_ENV DATA_CONSUMER_IMAGE=notip-data-consumer:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-data-consumer:local" ;; \
	      provisioning|provisioning-service) \
	        COMPOSE_ENV="$$COMPOSE_ENV PROVISIONING_IMAGE=notip-provisioning-service:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-provisioning-service:local" ;; \
	      frontend|notip-frontend) \
	        COMPOSE_ENV="$$COMPOSE_ENV FRONTEND_IMAGE=notip-frontend:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-frontend:local" ;; \
	      simulator|simulator-backend|notip-simulator-backend) \
	        COMPOSE_ENV="$$COMPOSE_ENV SIMULATOR_IMAGE=notip-simulator-backend:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-simulator-backend:local" ;; \
	      sim-cli|cli) \
	        COMPOSE_ENV="$$COMPOSE_ENV SIM_CLI_IMAGE=notip-simulator-cli:local"; \
	        LOCAL_IMAGES="$$LOCAL_IMAGES notip-simulator-cli:local" ;; \
	      '') ;; \
	      *) \
	        echo "Unknown local service '$$svc'."; \
	        echo "Valid values: management-api,data-api,data-consumer,provisioning-service,frontend,simulator,sim-cli"; \
	        exit 1 ;; \
	    esac; \
	  done; \
	  for image in $$LOCAL_IMAGES; do \
	    echo "Building local image '$$image'..."; \
	    case "$$image" in \
	      notip-management-api:local) docker build --target prod -t "$$image" ../../notip-management-api ;; \
	      notip-data-api:local) docker build --target prod -t "$$image" ../../notip-data-api ;; \
	      notip-data-consumer:local) docker build --target prod -t "$$image" ../../notip-data-consumer ;; \
	      notip-provisioning-service:local) docker build --target prod -t "$$image" ../../notip-provisioning-service ;; \
	      notip-frontend:local) docker build --target prod -t "$$image" ../../notip-frontend ;; \
	      notip-simulator-backend:local) docker build --target prod -t "$$image" ../../notip-simulator-backend ;; \
	      notip-simulator-cli:local) docker build --target prod -t "$$image" ../../notip-simulator-cli ;; \
	      *) echo "No build rule configured for local image '$$image'."; exit 1 ;; \
	    esac; \
	  done; \
	  echo "Using local images for: $$LOCAL_SERVICES"; \
	fi; \
	if [ "$$SKIP_PULL" -eq 0 ]; then \
	  $(COMPOSE_CMD) pull; \
	else \
	  echo "Skipping explicit pull because local image tags are selected."; \
	fi; \
	eval "$$COMPOSE_ENV $(COMPOSE_CMD) up -d"

# Destroy everything including the CA volume.
# ⚠ This invalidates ALL provisioned gateway certificates.
reset-all:
	@echo "WARNING: This will destroy CA volume and invalidate all gateway certs."
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	$(COMPOSE_CMD) down -v

logs:
	${COMPOSE_CMD} logs -f

logs-svc:
	${COMPOSE_CMD} logs -f $(SVC)

ps:
	$(COMPOSE_CMD) ps

keycloak-import:
	@bash scripts/keycloak-import.sh

health:
	@bash scripts/healthcheck.sh

lint:
	pre-commit run --all-files


migration-run-management:
	$(COMPOSE_CMD) exec -T management-api node ./node_modules/typeorm/cli.js -d dist/src/database/data-source.js migration:run

migration-revert-management:
	$(COMPOSE_CMD) exec -T management-api node ./node_modules/typeorm/cli.js -d dist/src/database/data-source.js migration:revert

migration-run-data:
	$(COMPOSE_CMD) exec -T data-api node ./node_modules/typeorm/cli.js -d dist/src/database/data-source.js migration:run

migration-revert-data:
	$(COMPOSE_CMD) exec -T data-api node ./node_modules/typeorm/cli.js -d dist/src/database/data-source.js migration:revert

migration-run-all: migration-run-management migration-run-data

migration-revert-all: migration-revert-data migration-revert-management

migration-run: migration-run-management

migration-revert: migration-revert-management
