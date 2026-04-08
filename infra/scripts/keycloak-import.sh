
#!/usr/bin/env bash
# Imports the notip realm and configures service account secrets + roles.
# Idempotent: skips realm import if it already exists.
set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-http://keycloak:8080}"
echo "DEBUG: KEYCLOAK_URL is $KEYCLOAK_URL"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD}"
MGMT_SECRET="${KEYCLOAK_MGMT_CLIENT_SECRET}"
SIM_SECRET="${KEYCLOAK_SIMULATOR_CLIENT_SECRET}"
REALM_FILE="/keycloak/realm-export.json"
RENDERED_REALM_FILE="$(mktemp)"

cleanup() {
  rm -f "$RENDERED_REALM_FILE"
}
trap cleanup EXIT

render_realm_file() {
  jq \
    --arg admin_user "$KEYCLOAK_ADMIN_USER" \
    --arg admin_password "$KEYCLOAK_ADMIN_PASSWORD" \
    '
      .users = ((.users // []) | map(
        if .username == "__KEYCLOAK_ADMIN_USER__" then
          .username = $admin_user
          | .credentials = ((.credentials // []) | map(
              if .type == "password" and .value == "__KEYCLOAK_ADMIN_PASSWORD__" then
                .value = $admin_password
                | .temporary = false
              else
                .
              end
            ))
        else
          .
        end
      ))
    ' \
    "$REALM_FILE" > "$RENDERED_REALM_FILE"
}

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
  render_realm_file
  curl -sf -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "$KEYCLOAK_URL/auth/admin/realms" \
    -d @"$RENDERED_REALM_FILE"
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

get_client_scope_uuid() {
  local scope_name="$1"
  curl -sf \
    -H "Authorization: Bearer $TOKEN" \
    "$KEYCLOAK_URL/auth/admin/realms/notip/client-scopes" \
    | jq -r --arg name "$scope_name" '.[] | select(.name == $name) | .id' \
    | head -n1
}

ensure_scope_mapper() {
  local scope_id="$1"
  local mapper_name="$2"
  local mapper_type="$3"
  local mapper_config="$4"

  local exists
  exists=$(curl -sf \
    -H "Authorization: Bearer $TOKEN" \
    "$KEYCLOAK_URL/auth/admin/realms/notip/client-scopes/$scope_id/protocol-mappers/models" \
    | jq -r --arg name "$mapper_name" 'map(select(.name == $name)) | length')

  if [ "$exists" = "0" ]; then
    curl -sf -X POST \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      "$KEYCLOAK_URL/auth/admin/realms/notip/client-scopes/$scope_id/protocol-mappers/models" \
      -d "{\"name\":\"$mapper_name\",\"protocol\":\"openid-connect\",\"protocolMapper\":\"$mapper_type\",\"consentRequired\":false,\"config\":$mapper_config}" \
      >/dev/null
  fi
}

ensure_mgmt_audience_mapper() {
  echo "==> Ensuring audience mapper for notip-mgmt-backend"

  local claims_scope_id
  claims_scope_id=$(get_client_scope_uuid "notip-claims")

  if [ -z "$claims_scope_id" ] || [ "$claims_scope_id" = "null" ]; then
    echo "  WARNING: notip-claims scope not found — skipping audience mapper."
    return
  fi

  ensure_scope_mapper \
    "$claims_scope_id" \
    "mgmt-audience-mapper" \
    "oidc-audience-mapper" \
    '{"included.client.audience":"notip-mgmt-backend","id.token.claim":"false","access.token.claim":"true","introspection.token.claim":"true"}'

  echo "  done."
}

ensure_sub_mapper() {
  echo "==> Ensuring sub mapper in notip-claims"

  local claims_scope_id
  claims_scope_id=$(get_client_scope_uuid "notip-claims")

  if [ -z "$claims_scope_id" ] || [ "$claims_scope_id" = "null" ]; then
    echo "  WARNING: notip-claims scope not found — skipping sub mapper."
    return
  fi

  ensure_scope_mapper \
    "$claims_scope_id" \
    "sub-mapper" \
    "oidc-usermodel-property-mapper" \
    '{"user.attribute":"id","claim.name":"sub","jsonType.label":"String","id.token.claim":"false","access.token.claim":"true","userinfo.token.claim":"false","introspection.token.claim":"true"}'

  echo "  done."
}
ensure_sub_impersonation_scope() {
  echo "==> Ensuring act.sub mapper in notip-claims"

  local claims_scope_id
  claims_scope_id=$(get_client_scope_uuid "notip-claims")

  if [ -z "$claims_scope_id" ] || [ "$claims_scope_id" = "null" ]; then
    echo "  WARNING: notip-claims scope not found — skipping username mapper."
    return
  fi

  ensure_scope_mapper \
    "$claims_scope_id" \
    "act-sub-impersonation" \
    "oidc-usersessionmodel-note-mapper" \
    '{"user.session.note":"IMPERSONATOR_ID","claim.name":"act.sub","jsonType.label":"String","id.token.claim":"true","access.token.claim":"true","userinfo.token.claim":"true","introspection.token.claim":"true"}'

  echo "  done."
}

ensure_username_mapper() {
  echo "==> Ensuring username mapper in notip-claims"

  local claims_scope_id
  claims_scope_id=$(get_client_scope_uuid "notip-claims")

  if [ -z "$claims_scope_id" ] || [ "$claims_scope_id" = "null" ]; then
    echo "  WARNING: notip-claims scope not found — skipping username mapper."
    return
  fi

  ensure_scope_mapper \
    "$claims_scope_id" \
    "username" \
    "oidc-usermodel-attribute-mapper" \
    '{"user.attribute":"username","claim.name":"username","jsonType.label":"String","id.token.claim":"true","access.token.claim":"true","userinfo.token.claim":"true"}'

  echo "  done."
}

ensure_user_profile_settings() {
  echo "==> Ensuring realm user profile settings"

  local profile_json
  local patched_profile_json

  profile_json=$(curl -sf \
    -H "Authorization: Bearer $TOKEN" \
    "$KEYCLOAK_URL/auth/admin/realms/notip/users/profile")

  patched_profile_json=$(echo "$profile_json" | jq '
    .unmanagedAttributePolicy = "ADMIN_EDIT"
    | .attributes = ((.attributes // []) | map(
        if (.name == "firstName" or .name == "lastName") then
          del(.required)
        else
          .
        end
      ))
  ')

  curl -sf -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    "$KEYCLOAK_URL/auth/admin/realms/notip/users/profile" \
    -d "$patched_profile_json" \
    >/dev/null

  echo "  done."
}

ensure_user_client_role() {
  local user_id="$1"
  local client_uuid="$2"
  local role_name="$3"

  local assigned
  assigned=$(curl -sf \
    -H "Authorization: Bearer $TOKEN" \
    "$KEYCLOAK_URL/auth/admin/realms/notip/users/$user_id/role-mappings/clients/$client_uuid" \
    | jq -r --arg rn "$role_name" 'map(select(.name == $rn)) | length')

  if [ "$assigned" = "0" ]; then
    local role_json
    role_json=$(curl -sf \
      -H "Authorization: Bearer $TOKEN" \
      "$KEYCLOAK_URL/auth/admin/realms/notip/clients/$client_uuid/roles/$role_name")

    curl -sf -X POST \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      "$KEYCLOAK_URL/auth/admin/realms/notip/users/$user_id/role-mappings/clients/$client_uuid" \
      -d "[$role_json]" \
      >/dev/null
  fi
}

ensure_mgmt_realm_management_roles() {
  local mgmt_sa_user_id="$1"

  echo "==> Ensuring realm-management roles for notip-mgmt-backend service account"

  local realm_mgmt_uuid
  realm_mgmt_uuid=$(get_client_uuid "realm-management")

  if [ -z "$realm_mgmt_uuid" ] || [ "$realm_mgmt_uuid" = "null" ]; then
    echo "  WARNING: realm-management client not found — skipping role assignment."
    return
  fi

  local required_roles=(
    manage-users
    view-users
    query-users
    query-groups
    view-clients
    manage-clients
    view-realm
    impersonation
  )

  for role_name in "${required_roles[@]}"; do
    ensure_user_client_role "$mgmt_sa_user_id" "$realm_mgmt_uuid" "$role_name"
  done

  echo "  done."
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

ensure_mgmt_audience_mapper
ensure_sub_mapper
ensure_sub_impersonation_scope
ensure_username_mapper
ensure_user_profile_settings

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

ensure_mgmt_realm_management_roles "$MGMT_SA_ID"

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

echo ""
echo "==> Keycloak initialization complete."
