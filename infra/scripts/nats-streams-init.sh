#!/bin/sh
# Creates or updates JetStream streams from nats/streams/*.json.
set -eu

# mTLS: connect using the management-api client cert.
NATS_URL="${NATS_URL:-nats://nats:4222}"
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
# Use nats stream ls instead of server check jetstream as server commands
# require a system account, while stream commands work with default permissions.
until nats_cmd stream ls > /dev/null 2>&1; do
  echo "  NATS not ready, retrying in 2s..."
  sleep 2
done
echo "  NATS ready."

echo "==> Syncing JetStream streams"
# Check if any .json files exist before looping
if ls "$STREAMS_DIR"/*.json >/dev/null 2>&1; then
  for config_file in "$STREAMS_DIR"/*.json; do
    stream_name=$(basename "$config_file" .json)
    if nats_cmd stream info "$stream_name" > /dev/null 2>&1; then
      echo "  exists: $stream_name (updating ...)"
      nats_cmd stream update "$stream_name" --config "$config_file" --force
    else
      nats_cmd stream add "$stream_name" --config "$config_file" --defaults
      echo "  created: $stream_name"
    fi
  done
else
  echo "  No stream configs found in $STREAMS_DIR"
fi

echo "==> Streams ready."
