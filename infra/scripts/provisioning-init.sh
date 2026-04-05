#!/usr/bin/env bash
# Generates CA, NATS server cert, and per-service mTLS client certs.
# Public certs/keys are written to /certs, while CA private material lives in
# /ca-private to avoid exposing the CA key to all services.
# Idempotent: skips files that already exist.
set -euo pipefail

CERTS_DIR="${CERTS_DIR:-/certs}"
CA_PRIVATE_DIR="${CA_PRIVATE_DIR:-/ca-private}"
CA_KEY_PATH="$CA_PRIVATE_DIR/ca.key"
CA_SERIAL_PATH="$CA_PRIVATE_DIR/ca.srl"
PROVISIONING_UID="${PROVISIONING_UID:-1000}"
PROVISIONING_GID="${PROVISIONING_GID:-1000}"
DATA_API_UID="${DATA_API_UID:-1000}"
DATA_API_GID="${DATA_API_GID:-1000}"
MANAGEMENT_API_UID="${MANAGEMENT_API_UID:-1000}"
MANAGEMENT_API_GID="${MANAGEMENT_API_GID:-1000}"
DATA_CONSUMER_UID="${DATA_CONSUMER_UID:-999}"
DATA_CONSUMER_GID="${DATA_CONSUMER_GID:-999}"
SIMULATOR_UID="${SIMULATOR_UID:-999}"
SIMULATOR_GID="${SIMULATOR_GID:-999}"
MEASURES_DB_UID="${MEASURES_DB_UID:-70}"
MEASURES_DB_GID="${MEASURES_DB_GID:-70}"
mkdir -p "$CERTS_DIR" "$CA_PRIVATE_DIR"

ca_cert_is_valid_ca() {
  [ -f "$CERTS_DIR/ca.crt" ] || return 1
  openssl x509 -in "$CERTS_DIR/ca.crt" -noout -text 2>/dev/null \
    | grep -q "CA:TRUE"
}

migrate_legacy_ca_private() {
  # One-time migration from older layouts that stored ca.key under /certs.
  if [ ! -f "$CA_KEY_PATH" ] && [ -f "$CERTS_DIR/ca.key" ]; then
    mv "$CERTS_DIR/ca.key" "$CA_KEY_PATH"
  fi
  if [ ! -f "$CA_SERIAL_PATH" ] && [ -f "$CERTS_DIR/ca.srl" ]; then
    mv "$CERTS_DIR/ca.srl" "$CA_SERIAL_PATH"
  fi
}

fix_permissions() {
  # Keep private keys restricted, then grant ownership to the non-root
  # services that must read them.
  chmod 600 "$CERTS_DIR"/*.key 2>/dev/null || true
  chmod 644 "$CERTS_DIR"/*.crt 2>/dev/null || true
  chmod 600 "$CA_KEY_PATH" 2>/dev/null || true
  chmod 600 "$CA_SERIAL_PATH" 2>/dev/null || true

  if [ -f "$CA_KEY_PATH" ]; then
    chown "${PROVISIONING_UID}:${PROVISIONING_GID}" "$CA_KEY_PATH"
  fi
  if [ -f "$CA_SERIAL_PATH" ]; then
    chown "${PROVISIONING_UID}:${PROVISIONING_GID}" "$CA_SERIAL_PATH"
  fi
  if [ -f "$CERTS_DIR/provisioning.key" ]; then
    chown "${PROVISIONING_UID}:${PROVISIONING_GID}" "$CERTS_DIR/provisioning.key"
  fi
  if [ -f "$CERTS_DIR/data-api.key" ]; then
    chown "${DATA_API_UID}:${DATA_API_GID}" "$CERTS_DIR/data-api.key"
  fi
  if [ -f "$CERTS_DIR/management-api.key" ]; then
    chown "${MANAGEMENT_API_UID}:${MANAGEMENT_API_GID}" "$CERTS_DIR/management-api.key"
  fi
  if [ -f "$CERTS_DIR/data-consumer.key" ]; then
    chown "${DATA_CONSUMER_UID}:${DATA_CONSUMER_GID}" "$CERTS_DIR/data-consumer.key"
  fi
  if [ -f "$CERTS_DIR/simulator.key" ]; then
    chown "${SIMULATOR_UID}:${SIMULATOR_GID}" "$CERTS_DIR/simulator.key"
  fi
  if [ -f "$CERTS_DIR/measures-db.key" ]; then
    chown "${MEASURES_DB_UID}:${MEASURES_DB_GID}" "$CERTS_DIR/measures-db.key"
  fi

  # Enforce CA key isolation from the shared certs mount.
  rm -f "$CERTS_DIR/ca.key" "$CERTS_DIR/ca.srl"
}

migrate_legacy_ca_private

if [ -f "$CA_KEY_PATH" ] && [ -f "$CERTS_DIR/ca.crt" ] && ! ca_cert_is_valid_ca; then
  echo "==> Existing CA cert is not a valid CA (missing CA:TRUE). Regenerating cert chain."
  rm -f "$CA_KEY_PATH" "$CA_SERIAL_PATH"
  rm -f "$CERTS_DIR"/*.crt "$CERTS_DIR"/*.key 2>/dev/null || true
fi

# ── CA ────────────────────────────────────────────────────────────────────────
if [ ! -f "$CA_KEY_PATH" ] || [ ! -f "$CERTS_DIR/ca.crt" ]; then
  # CA key/cert must stay coherent with all leaf certs. If one is missing,
  # force full leaf regeneration to avoid stale certs signed by another CA.
  rm -f "$CA_KEY_PATH" "$CA_SERIAL_PATH"
  rm -f "$CERTS_DIR"/*.crt "$CERTS_DIR"/*.key 2>/dev/null || true

  echo "==> Generating CA"
  ca_ext_file=$(mktemp)
  cat > "$ca_ext_file" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3_ca
[dn]
[v3_ca]
basicConstraints = critical,CA:true
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF
  openssl genrsa -out "$CA_KEY_PATH" 4096
  openssl req -new -x509 -days 3650 \
    -key "$CA_KEY_PATH" \
    -out "$CERTS_DIR/ca.crt" \
    -subj "/CN=notip-ca/O=notip" \
    -config "$ca_ext_file" \
    -extensions v3_ca
  rm -f "$ca_ext_file"
  chmod 600 "$CA_KEY_PATH"
  echo "    done: ca.key + ca.crt"
else
  echo "==> CA exists, reusing."
fi

# ── Helper: sign a cert with our CA ──────────────────────────────────────────
# san_extra: optional additional SANs e.g. "DNS:nats,IP:127.0.0.1"
gen_cert() {
  local name="$1"
  local san="${2:-}"
  local ca_serial_args

  if [ -f "$CA_SERIAL_PATH" ]; then
    ca_serial_args=( -CAserial "$CA_SERIAL_PATH" )
  else
    ca_serial_args=( -CAserial "$CA_SERIAL_PATH" -CAcreateserial )
  fi

  if [ -f "$CERTS_DIR/${name}.crt" ] && [ -f "$CERTS_DIR/${name}.key" ]; then
    echo "    exists: ${name} (skipped)"
    return
  fi

  openssl genrsa -out "$CERTS_DIR/${name}.key" 2048
  chmod 600 "$CERTS_DIR/${name}.key"

  local ext_file
  ext_file=$(mktemp)

  if [ -n "$san" ]; then
    cat > "$ext_file" <<EOF
[req]
req_extensions = v3_req
distinguished_name = dn
[dn]
[v3_req]
subjectAltName = ${san}
EOF
    openssl req -new \
      -key "$CERTS_DIR/${name}.key" \
      -out "$CERTS_DIR/${name}.csr" \
      -subj "/CN=${name}/O=notip" \
      -config "$ext_file"
    openssl x509 -req -days 3650 \
      -in "$CERTS_DIR/${name}.csr" \
      -CA "$CERTS_DIR/ca.crt" \
      -CAkey "$CA_KEY_PATH" \
      "${ca_serial_args[@]}" \
      -extfile "$ext_file" \
      -extensions v3_req \
      -out "$CERTS_DIR/${name}.crt"
  else
    openssl req -new \
      -key "$CERTS_DIR/${name}.key" \
      -out "$CERTS_DIR/${name}.csr" \
      -subj "/CN=${name}/O=notip"
    openssl x509 -req -days 3650 \
      -in "$CERTS_DIR/${name}.csr" \
      -CA "$CERTS_DIR/ca.crt" \
      -CAkey "$CA_KEY_PATH" \
      "${ca_serial_args[@]}" \
      -out "$CERTS_DIR/${name}.crt"
  fi

  rm -f "$CERTS_DIR/${name}.csr" "$ext_file"
  echo "    generated: ${name}.crt + ${name}.key"
}

# ── NATS server cert (needs SANs so Go TLS clients accept it) ─────────────────
echo "==> Generating NATS server cert"
gen_cert "nats" "DNS:nats,DNS:localhost,IP:127.0.0.1"

echo "==> Generating measures-db server cert"
gen_cert "measures-db" "DNS:measures-db,DNS:localhost,IP:127.0.0.1"

# ── Per-service mTLS client certs ─────────────────────────────────────────────
# CN must match the `user` entry in nats-server.conf authorization block.
echo "==> Generating service client certs"
gen_cert "management-api"
gen_cert "data-api"
gen_cert "data-consumer"
gen_cert "provisioning"
gen_cert "simulator"

fix_permissions

echo ""
echo "==> All certs ready:"
ls -la "$CERTS_DIR"
echo ""
echo "==> CA private material:"
ls -la "$CA_PRIVATE_DIR"
