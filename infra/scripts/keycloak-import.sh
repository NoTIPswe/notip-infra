#!/usr/bin/env bash
# Imports the notip realm and configures service account secrets + roles.
# Idempotent: skips realm import if it already exists.
set -euo pipefail
SECRETS_DIR="/run/secrets"
if [ ! -d "$SECRETS_DIR" ]; then
  SECRETS_DIR="./secrets"
fi

KEYCLOAK_URL="${KEYCLOAK_URL:-http://keycloak:8080}"
echo "DEBUG: KEYCLOAK_URL is $KEYCLOAK_URL"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="$(cat $SECRETS_DIR/keycloak_admin_password)"
MGMT_SECRET="$(cat $SECRETS_DIR/keycloak_mgmt_client_secret)"
SIM_SECRET="$(cat $SECRETS_DIR/keycloak_simulator_client_secret)"
REALM_FILE="/keycloak/realm-export.json"

# Wait for Keycloak
echo "==> Waiting for Keycloak"
# Keycloak 26.5 management interface is on port 9000.
# We replace :8080 with :9000 for the health check.
KEYCLOAK_MGMT_URL="${KEYCLOAK_URL/8080/9000}"

until curl -sf "$KEYCLOAK_MGMT_URL/auth/health/ready" > /dev/null 2>&1; do
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

# Keycloak 26 requires the full user object (including username) for PUT.
MGMT_SA_JSON=$(curl -sSf \
  -H "Authorization: Bearer $TOKEN" \
  "$KEYCLOAK_URL/auth/admin/realms/notip/clients/$MGMT_UUID/service-account-user")
MGMT_SA_ID=$(echo "$MGMT_SA_JSON" | jq -r '.id')
MGMT_SA_NAME=$(echo "$MGMT_SA_JSON" | jq -r '.username')


# Set role user attribute so the JWT carries role=system_admin
echo "==> Setting role=system_admin attribute on service account"
curl -sSf -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$KEYCLOAK_URL/auth/admin/realms/notip/users/$MGMT_SA_ID" \
  -d "{\"username\":\"$MGMT_SA_NAME\",\"attributes\":{\"role\":[\"system_admin\"]}}" || { echo "Failed to set attribute for MGMT_SA_ID"; exit 1; }
echo "  done."

# Assign system_admin to notip-simulator-backend service account
echo "==> Setting role=system_admin on notip-simulator-backend service account"
SIM_UUID=$(get_client_uuid "notip-simulator-backend")

SIM_SA_JSON=$(curl -sSf \
  -H "Authorization: Bearer $TOKEN" \
  "$KEYCLOAK_URL/auth/admin/realms/notip/clients/$SIM_UUID/service-account-user")
SIM_SA_ID=$(echo "$SIM_SA_JSON" | jq -r '.id')
SIM_SA_NAME=$(echo "$SIM_SA_JSON" | jq -r '.username')


curl -sSf -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "$KEYCLOAK_URL/auth/admin/realms/notip/users/$SIM_SA_ID" \
  -d "{\"username\":\"$SIM_SA_NAME\",\"attributes\":{\"role\":[\"system_admin\"]}}" || { echo "Failed to set attribute for SIM_SA_ID"; exit 1; }
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
