#!/usr/bin/env bash
# Script per build e push dei target base e dev (multi-arch) su GHCR
# Uso:     ./release-dev.sh <stack> <versione>
# Esempio: ./release-dev.sh nest v1.2.0

set -euo pipefail

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
    echo "❌ Errore: Parametri mancanti."
    echo "💡 Uso corretto: ./release-dev.sh <stack> <versione>"
    echo "💡 Esempio:      ./release-dev.sh nest v1.2.0"
    exit 1
fi

STACK=$1
VERSION=$2
GHCR_ORG="${GHCR_ORG:-notipswe}"
PLATFORMS="linux/amd64,linux/arm64"

cd "$(dirname "$0")"

# Verifica stack
if [ ! -d "$STACK" ]; then
    echo "❌ Errore: La cartella '$STACK' non esiste in containers/."
    exit 1
fi

echo "🚀 Inizializzazione di Docker Buildx..."
if ! docker info >/dev/null 2>&1; then
    echo "❌ Errore: Docker daemon non raggiungibile."
    echo "💡 Verifica che il daemon Docker sia attivo nel tuo ambiente (DinD/rootless o host daemon)."
    exit 1
fi

if ! docker buildx inspect notip-builder >/dev/null 2>&1; then
    docker buildx create --name notip-builder --driver docker-container >/dev/null
fi

docker buildx use notip-builder
docker buildx inspect --bootstrap >/dev/null

echo "------------------------------------------------------"
echo "📦 Building and Pushing: $STACK"
echo "🏢 Org: $GHCR_ORG"
echo "🏗️  Stages: base, dev"
echo "🏗️  Platforms: $PLATFORMS"
echo "------------------------------------------------------"

for STAGE in base dev; do
    IMAGE_NAME="notip-$STACK-$STAGE"
    IMAGE_TAG="ghcr.io/$GHCR_ORG/$IMAGE_NAME:$VERSION"

    echo "------------------------------------------------------"
    echo "🎯 Stage: $STAGE"
    echo "🧱 Image: $IMAGE_NAME"
    echo "🏷️  Tag: $IMAGE_TAG"

    docker buildx build \
        --target "$STAGE" \
        --platform "$PLATFORMS" \
        -t "$IMAGE_TAG" \
        -f "$STACK/Dockerfile" \
        "$STACK" \
        --push
done

echo "✅ $STACK (base + dev) [$VERSION] rilasciato con successo su GHCR!"
