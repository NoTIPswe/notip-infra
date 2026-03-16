#!/usr/bin/env bash
# Imports the notip realm and configures service account secrets + roles.
# Idempotent: skips realm import if it already exists.
set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-http://keycloak:8080}"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="$(cat /run/secrets/keycloak_admin_password)"
MGMT_SECRET="$(cat /run/secrets/keycloak_mgmt_client_secret)"
SIM_SECRET="$(cat /run/secrets/keycloak_simulator_client_secret)"
REALM_FILE="/keycloak/realm-export.json"

# Wait for Keycloak 
echo "==> Waiting for Keycloak"
until curl -sf "$KEYCLOAK_URL/auth/health/ready" > /dev/null 2>&1; do
  echo "  not ready, retrying in 3s..."
  sleep 3
done
echo "  ready."

# Admin token 
get_token() {
  curl -sf \
    "$KEYCLOAK_URL/auth/realms/master/protocol/openid-connect/token" \
    -d "client_id=admin-cli" \
    -d "username=$KEYCLOAK_ADMIN_USER" \
    --data-urlencode "password=$KEYCLOAK_ADMIN_PASSWORD" \
    -d "grant_type=password" \
    | jq -r '.access_token'
}

TOKEN=$(get_token)

# Import realm 
echo "==> Checking realm 'notip'"
HTTP_STATUS=$(curl -so /dev/null -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  "$KEYCLOAK_URL/auth/admin/realms/notip")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "  exists, skipping import."
else
  echo "  importing..."
  curl -sf -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "$KEYCLOAK_URL/auth/admin/realms" \
    -d @"$REALM_FILE"
  echo "  done."
  TOKEN=$(get_token)
fi

# Helper: get internal UUID for a client 
get_client_uuid() {
  curl -sf \
    -H "Authorization: Bearer $TOKEN" \
    "$KEYCLOAK_URL/auth/admin/realms/notip/clients?clientId=$1" \
    | jq -r '.[0].id'
}

# Helper: set client secret 
set_client_secret() {
  local client_id="$1"
  local secret="$2"
  local uuid
  uuid=$(get_client_uuid "$client_id")
  echo "==> Setting secret for $client_id"
  curl -sf -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "$KEYCLOAK_URL/auth/admin/realms/notip/clients/$uuid" \
    -d "{\"secret\":\"$secret\"}"
  echo "  done."
}

set_client_secret "notip-mgmt-backend"      "$MGMT_SECRET"
set_client_secret "notip-simulator-backend" "$SIM_SECRET"

# Assign system_admin role to notip-mgmt-backend service account 
echo "==> Assigning manage-clients role to notip-mgmt-backend service account"
MGMT_UUID=$(get_client_uuid "notip-mgmt-backend")
MGMT_SA_ID=$(curl -sf \
  -H "Authorization: Bearer $TOKEN" \
  "$KEYCLOAK_URL/auth/admin/realms/notip/clients/$MGMT_UUID/service-account-user" \
  | jq -r '.id')

# Set role user attribute so the JWT carries role=system_admin
curl -sf -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$KEYCLOAK_URL/auth/admin/realms/notip/users/$MGMT_SA_ID" \
  -d '{"attributes":{"role":["system_admin"]}}'
echo "  done."

# Assign system_admin to notip-simulator-backend service account 
echo "==> Setting role=system_admin on notip-simulator-backend service account"
SIM_UUID=$(get_client_uuid "notip-simulator-backend")
SIM_SA_ID=$(curl -sf \
  -H "Authorization: Bearer $TOKEN" \
  "$KEYCLOAK_URL/auth/admin/realms/notip/clients/$SIM_UUID/service-account-user" \
  | jq -r '.id')

curl -sf -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$KEYCLOAK_URL/auth/admin/realms/notip/users/$SIM_SA_ID" \
  -d '{"attributes":{"role":["system_admin"]}}'
echo "  done."

# Grant manage-clients realm role to notip-mgmt-backend 
echo "==> Granting manage-clients realm role to notip-mgmt-backend"
MANAGE_CLIENTS_ROLE=$(curl -sf \
  -H "Authorization: Bearer $TOKEN" \
  "$KEYCLOAK_URL/auth/admin/realms/notip/roles/manage-clients" 2>/dev/null || echo "null")

if [ "$MANAGE_CLIENTS_ROLE" = "null" ]; then
  echo "  WARNING: manage-clients role not found at realm level — skipping."
  echo "  Grant it manually: Keycloak Admin > notip-mgmt-backend > Service Account Roles > Client Roles > realm-management > manage-clients"
else
  curl -sf -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "$KEYCLOAK_URL/auth/admin/realms/notip/users/$MGMT_SA_ID/role-mappings/realm" \
    -d "[$MANAGE_CLIENTS_ROLE]"
  echo "  done."
fi

echo ""
echo "==> Keycloak initialization complete."
