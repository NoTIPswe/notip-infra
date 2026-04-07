#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
ENV_EXAMPLE="$REPO_ROOT/.env.example"

echo "==> .env"
if [ ! -f "$ENV_FILE" ]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "  created .env from .env.example -- fill in non-secret values"
else
    echo "  exists (skipped)"
fi

echo "==> generating secrets in .env"

gen_secret() {
    local env_var="$1"
    local current_value
    current_value=$(grep -E "^${env_var}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2-)
    if [ -n "$current_value" ]; then
        echo "  $env_var (exists, skipped)"
        return
    fi
    local value
    value=$(openssl rand -hex 32)
    echo "${env_var}=${value}" >> "$ENV_FILE"
    echo "  $env_var"
}

gen_secret DB_ENCRYPTION_KEY
gen_secret MGMT_DB_PASSWORD
gen_secret MEASURES_DB_PASSWORD
gen_secret KEYCLOAK_ADMIN_PASSWORD
gen_secret KEYCLOAK_MGMT_CLIENT_SECRET
gen_secret KEYCLOAK_SIMULATOR_CLIENT_SECRET
gen_secret KEYCLOAK_DB_PASSWORD

echo ""
echo "Bootstrap complete. Next: make up"