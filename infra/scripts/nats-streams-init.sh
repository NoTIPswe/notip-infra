#!/usr/bin/env bash
# Creates or updates JetStream streams from nats/streams/*.json.
set -euo pipefail
shopt -s nullglob # Prevent loop from running if no .json files exist

# mTLS: connect using the management-api client cert.
NATS_URL="${NATS_URL:-tls://nats:4222}"
STREAMS_DIR="/streams"
NATS_CA="${NATS_CA:-/certs/ca.crt}"
NATS_CERT="${NATS_CERT:-/certs/management-api.crt}"
NATS_KEY="${NATS_KEY:-/certs/management-api.key}"

nats_cmd() {
  nats --server "$NATS_URL" \
       --tlsca   "$NATS_CA" \
       --tlscert "$NATS_CERT" \
       --tlskey  "$NATS_KEY" \
       "$@"
}

echo "==> Waiting for NATS at $NATS_URL"
until nats_cmd server check jetstream 2>/dev/null; do
  echo "  NATS not ready, retrying in 2s..."
  sleep 2
done
echo "  NATS ready."

echo "==> Syncing JetStream streams"
for config_file in "$STREAMS_DIR"/*.json; do
  stream_name=$(basename "$config_file" .json)
  if nats_cmd stream info "$stream_name" > /dev/null 2>&1; then
    echo "  exists: $stream_name (updating ...)"
    nats_cmd stream update --config "$config_file"
  else
    nats_cmd stream add --config "$config_file"
    echo "  created: $stream_name"
  fi
done

echo "==> Streams ready."
