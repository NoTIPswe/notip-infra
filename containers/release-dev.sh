#!/bin/bash
# Script per build e push di un singolo devcontainer (multi-arch) su GHCR
# Uso:     ./release-dev.sh <stack> <versione>
# Esempio: ./release-dev.sh nest v1.2.0

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
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
docker buildx create --use --name notip-builder 2>/dev/null || true

IMAGE_TAG="ghcr.io/$GHCR_ORG/notip-$STACK-dev:$VERSION"

echo "------------------------------------------------------"
echo "📦 Building and Pushing: $STACK"
echo "🏢 Org: $GHCR_ORG"
echo "🏷️  Tag: $IMAGE_TAG"
echo "🏗️  Platforms: $PLATFORMS"
echo "------------------------------------------------------"

docker buildx build \
    --target dev \
    --platform "$PLATFORMS" \
    -t "$IMAGE_TAG" \
    -f "$STACK/Dockerfile" \
    "$STACK" \
    --push

echo "✅ $STACK ($VERSION) rilasciato con successo su GHCR!"