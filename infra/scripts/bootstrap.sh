#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="$REPO_ROOT/secrets"
ENV_FILE="$REPO_ROOT/.env"
ENV_EXAMPLE="$REPO_ROOT/.env.example"

# ── helpers ──────────────────────────────────────────────────────────────────

gen_secret() {
  local file="$SECRETS_DIR/$1"
  if [ ! -f "$file" ] || [ ! -s "$file" ]; then     # checks it the file so not exits or if it's empty
    openssl rand -hex 32 > "$file"
    echo "  generated: secrets/$1"
  else
    echo "  exists:    secrets/$1 (skipped)"
  fi
}

# ── .env ─────────────────────────────────────────────────────────────────────

echo "==> .env"
if [ ! -f "$ENV_FILE" ]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "  created .env from .env.example -- fill in non-secret values"
else
    echo "  exists (skipped)"
fi

# ── secrets/ ─────────────────────────────────────────────────────────────────

echo "==> secrets/"
mkdir -p "$SECRETS_DIR"

gen_secret db_encryption_key
gen_secret mgmt_db_password
gen_secret measures_db_password
gen_secret keycloak_admin_password
gen_secret keycloak_mgmt_client_secret
gen_secret keycloak_simulator_client_secret
gen_secret keycloak_db_password

# ── sync secrets into .env ────────────────────────────────────────────────────
# For dev convenience, keep .env in sync with generated secrets so
# docker-compose.override.yml can use env_file instead of secrets: mounts.

echo "==> syncing secrets into .env"

sync_to_env() {
    local env_var="$1"
    local secret_file="$SECRETS_DIR/$2"
    local value
    value="$(cat "$secret_file")"
    #Replace the line if it exists, append if doesn't
    if grep -q "^${env_var}=" "$ENV_FILE"; then
        sed -i.bak "s|^${env_var}=.*|${env_var}=${value}|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    else
        echo "${env_var}=${value}" >> "$ENV_FILE"
    fi
}

sync_to_env DB_ENCRYPTION_KEY              db_encryption_key
sync_to_env MGMT_DB_PASSWORD               mgmt_db_password
sync_to_env MEASURES_DB_PASSWORD           measures_db_password
sync_to_env KEYCLOAK_ADMIN_PASSWORD        keycloak_admin_password
sync_to_env KEYCLOAK_MGMT_CLIENT_SECRET    keycloak_mgmt_client_secret
sync_to_env KEYCLOAK_SIMULATOR_CLIENT_SECRET keycloak_simulator_client_secret
sync_to_env KEYCLOAK_DB_PASSWORD keycloak_db_password

echo ""
echo "Bootstrap complete. Next: make up"
