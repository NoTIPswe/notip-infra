#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-compose/docker-compose.yml}"
COMPOSE_CMD=(docker compose --project-directory . -f "$COMPOSE_FILE")
FAILED=0
FOUND=0

is_one_shot_service() {
  case "$1" in
    provisioning-init|nats-streams-init|keycloak-init)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

echo "==> notip stack health (docker compose state)"
while IFS='|' read -r service state health exit_code; do
  [ -z "$service" ] && continue
  FOUND=1

  case "$state" in
    running)
      if [ -n "$health" ] && [ "$health" != "healthy" ]; then
        echo "  FAIL $service  (state=$state health=$health)"
        FAILED=1
      else
        if [ -n "$health" ]; then
          echo "  ok   $service  (state=$state health=$health)"
        else
          echo "  ok   $service  (state=$state)"
        fi
      fi
      ;;
    exited)
      if is_one_shot_service "$service" && [ "$exit_code" = "0" ]; then
        echo "  ok   $service  (one-shot completed)"
      else
        echo "  FAIL $service  (state=$state exit_code=$exit_code)"
        FAILED=1
      fi
      ;;
    restarting)
      echo "  FAIL $service  (restarting — crash loop?)"
      FAILED=1
      ;;
    *)
      echo "  FAIL $service  (state=$state health=$health exit_code=$exit_code)"
      FAILED=1
      ;;
  esac
done < <("${COMPOSE_CMD[@]}" ps --all --format '{{.Service}}|{{.State}}|{{.Health}}|{{.ExitCode}}')

if [ "$FOUND" -eq 0 ]; then
  echo ""
  echo "No compose services found. Run: make up"
  exit 1
fi

if [ "$FAILED" -ne 0 ]; then
  echo ""
  echo "One or more services unhealthy. Run: make ps, then make logs-svc SVC=<service>"
  exit 1
fi

echo ""
echo "All services healthy."
