COMPOSE_FILE := compose/docker-compose.yml
COMPOSE_MONITORING := compose/docker-compose.monitoring.yml
COMPOSE_CMD := docker compose --project-directory . -f ${COMPOSE_FILE}
COMPOSE_CMD_ALL := docker compose --project-directory . -f ${COMPOSE_FILE} --profile simulator --profile cli

define LOCAL_UP_SCRIPT
set -eu; \
LOCAL_SERVICES="$${LOCAL:-$${local:-}}"; \
COMPOSE_ENV=""; \
LOCAL_IMAGES=""; \
LOCAL_COMPOSE_SERVICES=""; \
if [ -n "$$LOCAL_SERVICES" ]; then \
  OLD_IFS="$$IFS"; IFS=','; set -- $$LOCAL_SERVICES; IFS="$$OLD_IFS"; \
  for raw in "$$@"; do \
    svc=$$(printf '%s' "$$raw" | tr -d '[:space:]'); \
    case "$$svc" in \
      management|management-api|mgmt) \
        COMPOSE_ENV="$$COMPOSE_ENV MGMT_API_IMAGE=notip-management-api:local"; \
        LOCAL_IMAGES="$$LOCAL_IMAGES notip-management-api:local"; \
        LOCAL_COMPOSE_SERVICES="$$LOCAL_COMPOSE_SERVICES management-api" ;; \
      data-api|data) \
        COMPOSE_ENV="$$COMPOSE_ENV DATA_API_IMAGE=notip-data-api:local"; \
        LOCAL_IMAGES="$$LOCAL_IMAGES notip-data-api:local"; \
        LOCAL_COMPOSE_SERVICES="$$LOCAL_COMPOSE_SERVICES data-api" ;; \
      data-consumer|consumer) \
        COMPOSE_ENV="$$COMPOSE_ENV DATA_CONSUMER_IMAGE=notip-data-consumer:local"; \
        LOCAL_IMAGES="$$LOCAL_IMAGES notip-data-consumer:local"; \
        LOCAL_COMPOSE_SERVICES="$$LOCAL_COMPOSE_SERVICES data-consumer" ;; \
      provisioning|provisioning-service) \
        COMPOSE_ENV="$$COMPOSE_ENV PROVISIONING_IMAGE=notip-provisioning-service:local"; \
        LOCAL_IMAGES="$$LOCAL_IMAGES notip-provisioning-service:local"; \
        LOCAL_COMPOSE_SERVICES="$$LOCAL_COMPOSE_SERVICES provisioning-service" ;; \
      frontend|notip-frontend) \
        COMPOSE_ENV="$$COMPOSE_ENV FRONTEND_IMAGE=notip-frontend:local"; \
        LOCAL_IMAGES="$$LOCAL_IMAGES notip-frontend:local"; \
        LOCAL_COMPOSE_SERVICES="$$LOCAL_COMPOSE_SERVICES frontend" ;; \
      simulator|simulator-backend|notip-simulator-backend) \
        COMPOSE_ENV="$$COMPOSE_ENV SIMULATOR_IMAGE=notip-simulator-backend:local"; \
        LOCAL_IMAGES="$$LOCAL_IMAGES notip-simulator-backend:local"; \
        LOCAL_COMPOSE_SERVICES="$$LOCAL_COMPOSE_SERVICES simulator" ;; \
      sim-cli|cli) \
        COMPOSE_ENV="$$COMPOSE_ENV SIM_CLI_IMAGE=notip-simulator-cli:local"; \
        LOCAL_IMAGES="$$LOCAL_IMAGES notip-simulator-cli:local"; \
        LOCAL_COMPOSE_SERVICES="$$LOCAL_COMPOSE_SERVICES sim-cli" ;; \
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
if [ -z "$$LOCAL_COMPOSE_SERVICES" ]; then \
  $(COMPOSE_CMD) pull; \
else \
  PULL_SERVICES=""; \
  for svc in $$($(COMPOSE_CMD) config --services); do \
    is_local=0; \
    for local_svc in $$LOCAL_COMPOSE_SERVICES; do \
      if [ "$$svc" = "$$local_svc" ]; then \
        is_local=1; \
        break; \
      fi; \
    done; \
    if [ "$$is_local" -eq 0 ]; then \
      PULL_SERVICES="$$PULL_SERVICES $$svc"; \
    fi; \
  done; \
  if [ -n "$$PULL_SERVICES" ]; then \
    echo "Pulling latest for non-local services:$$PULL_SERVICES"; \
    eval "$$COMPOSE_ENV $(COMPOSE_CMD) pull $$PULL_SERVICES"; \
  else \
    echo "No non-local services to pull."; \
  fi; \
fi; \
eval "$$COMPOSE_ENV $(COMPOSE_CMD) up -d"
endef

define RUN_MIGRATION
$(COMPOSE_CMD) exec -T $(1) node ./node_modules/typeorm/cli.js -d dist/src/database/data-source.js migration:$(2)
endef

.PHONY: bootstrap up up-with-migrations up-monitoring down reset reset-all logs ps keycloak-import health lint \
	migration-run migration-revert migration-run-management migration-revert-management \
	migration-run-data migration-revert-data migration-run-all migration-revert-all

bootstrap:
	@bash scripts/bootstrap.sh

up:
	@$(LOCAL_UP_SCRIPT)

up-monitoring:
	docker compose -f $(COMPOSE_MONITORING) up -d

up-with-migrations:
	@$(MAKE) up LOCAL="$(or $(LOCAL),$(local))"
	@$(MAKE) migration-run-all

down:
	$(COMPOSE_CMD) down

down-monitoring:
	docker compose -f $(COMPOSE_MONITORING) down

# Bring stack down and remove all named volumes EXCEPT notip_ca_certs
# Preserves provisioned gateway certificates.
reset:
	-docker compose -f $(COMPOSE_MONITORING) down
	$(COMPOSE_CMD_ALL) down
	@docker volume ls --format '{{.Name}}' \
	  | grep '^notip_' \
	  | grep -v 'notip_ca_certs' \
	  | xargs -r docker volume rm
	@$(LOCAL_UP_SCRIPT)

# Destroy everything including the CA volume.
# ⚠ This invalidates ALL provisioned gateway certificates.
reset-all:
	@echo "WARNING: This will destroy CA volume and invalidate all gateway certs."
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	-docker compose -f $(COMPOSE_MONITORING) down
	$(COMPOSE_CMD_ALL) down -v

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
	@$(call RUN_MIGRATION,management-api,run)

migration-revert-management:
	@$(call RUN_MIGRATION,management-api,revert)

migration-run-data:
	@$(call RUN_MIGRATION,data-api,run)

migration-revert-data:
	@$(call RUN_MIGRATION,data-api,revert)

migration-run-all: migration-run-management migration-run-data

migration-revert-all: migration-revert-data migration-revert-management

migration-run: migration-run-management

migration-revert: migration-revert-management
