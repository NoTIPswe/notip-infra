COMPOSE_FILE := compose/docker-compose.yml
COMPOSE_MONITORING := compose/docker-compose.monitoring.yml
COMPOSE_CMD := docker compose --project-directory . -f ${COMPOSE_FILE}

.PHONY: bootstrap up up-monitoring down reset reset-all logs ps keycloak-import health lint

bootstrap:
	@bash scripts/bootstrap.sh

up:
	$(COMPOSE_CMD) up -d

up-monitoring:
	docker compose -f $(COMPOSE_MONITORING) up -d

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
	$(COMPOSE_CMD) up -d

# Destroy everything including the CA volume.
# ⚠ This invalidates ALL provisioned gateway certificates.
reset-all: 
	@echo "WARNING: This will destroy CA volume and invalidate all gateway certs."
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y"]
	$(COMPOSE_CMD) down -v 

logs: 
	${COMPOSE_CMD} logs -f 

logs-svc: 
	${COMPOSE_CMD} logs -f $(SVC)

ps: 
	@bash scripts/keycloak-import.sh

health: 
	@bash scripts/healthcheck.sh

lint: 
	prec-commit run --all-files