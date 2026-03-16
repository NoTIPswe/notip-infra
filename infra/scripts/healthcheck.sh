#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE_URL:-http://localhost}"
FAILED=0

check() {
  local name="$1"
  local url="$2"
  if curl -sf --max-time 5 "$url" > /dev/null 2>&1; then
    echo "  ok  $name"
  else
    echo "  FAIL $name  ($url)"
    FAILED=1
  fi
}

echo "==> notip stack health"
check "nginx"          "$BASE/"
check "keycloak"       "$BASE/auth/health/ready"
check "management-api" "$BASE/api/mgmt/health"
check "data-api"       "$BASE/api/data/health"
check "provisioning"   "$BASE/api/provision/health"

if [ "$FAILED" -ne 0 ]; then
  echo ""
  echo "One or more services unhealthy. Run: make logs, to see more..."
  exit 1
fi

echo ""
echo "All services healthy."
