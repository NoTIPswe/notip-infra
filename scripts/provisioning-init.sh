#!/usr/bin/env bash
# Generates CA, NATS server cert, and per-service mTLS client certs.
# All written to /certs (notip_ca_certs Docker volume).
# Idempotent: skips files that already exist.
set -euo pipefail

CERTS_DIR="${CERTS_DIR:-/certs}"
mkdir -p "$CERTS_DIR"

# ── CA ────────────────────────────────────────────────────────────────────────
if [ ! -f "$CERTS_DIR/ca.key" ] || [ ! -f "$CERTS_DIR/ca.crt" ]; then
  echo "==> Generating CA"
  openssl genrsa -out "$CERTS_DIR/ca.key" 4096
  openssl req -new -x509 -days 3650 \
    -key "$CERTS_DIR/ca.key" \
    -out "$CERTS_DIR/ca.crt" \
    -subj "/CN=notip-ca/O=notip"
  chmod 600 "$CERTS_DIR/ca.key"
  echo "    done: ca.key + ca.crt"
else
  echo "==> CA exists, reusing."
fi

# ── Helper: sign a cert with our CA ──────────────────────────────────────────
# san_extra: optional additional SANs e.g. "DNS:nats,IP:127.0.0.1"
gen_cert() {
  local name="$1"
  local san="${2:-}"

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
      -CAkey "$CERTS_DIR/ca.key" \
      -CAcreateserial \
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
      -CAkey "$CERTS_DIR/ca.key" \
      -CAcreateserial \
      -out "$CERTS_DIR/${name}.crt"
  fi

  rm -f "$CERTS_DIR/${name}.csr" "$ext_file"
  echo "    generated: ${name}.crt + ${name}.key"
}

# ── NATS server cert (needs SANs so Go TLS clients accept it) ─────────────────
echo "==> Generating NATS server cert"
gen_cert "nats" "DNS:nats,DNS:localhost,IP:127.0.0.1"

# ── Per-service mTLS client certs ─────────────────────────────────────────────
# CN must match the `user` entry in nats-server.conf authorization block.
echo "==> Generating service client certs"
gen_cert "management-api"
gen_cert "data-api"
gen_cert "data-consumer"
gen_cert "provisioning"
gen_cert "simulator"

echo ""
echo "==> All certs ready:"
ls -la "$CERTS_DIR"
