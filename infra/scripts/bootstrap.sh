SECRETS_DIR="./secrets"

mkdir -p "$SECRETS_DIR"
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
    local value
    value=$(openssl rand -hex 32)
    if grep -qE "^${env_var}=" "$ENV_FILE"; then
        # Sostituisci la riga esistente
        sed -i "s|^${env_var}=.*|${env_var}=${value}|" "$ENV_FILE"
        echo "  $env_var (updated)"
    else
        echo "${env_var}=${value}" >> "$ENV_FILE"
        echo "  $env_var (added)"
    fi
    if [ "$env_var" = "MEASURES_DB_PASSWORD" ]; then
        echo -n "$value" > "$SECRETS_DIR/measures_db_password"
        chmod 600 "$SECRETS_DIR/measures_db_password"
        echo "  $env_var (and secrets/measures_db_password)"
    fi
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