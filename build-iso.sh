#!/bin/bash
# Build ttyai ISOs
set -e

EDITION="${1:-all}"
ARCH="${2:-both}"
DIST="dist"
mkdir -p "$DIST"

extract_iso() {
    local tag="$1" file="$2"
    docker rm -f "ttyai-extract-${tag}" 2>/dev/null || true
    docker create --name "ttyai-extract-${tag}" "ttyai/iso-builder:${tag}" /bin/true
    docker cp "ttyai-extract-${tag}:/build/ttyai.iso" "${DIST}/${file}"
    docker rm "ttyai-extract-${tag}"
    echo "  -> ${DIST}/${file} ($(du -h "${DIST}/${file}" | cut -f1))"
}

build_online() {
    if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "both" ]; then
        echo "=== Building Online ARM64 ISO ==="
        docker build --platform linux/arm64 \
            -f Dockerfile.iso-online \
            --target builder \
            -t ttyai/iso-builder:arm64 .
        extract_iso arm64 ttyai-arm64.iso
    fi

    if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "both" ]; then
        echo "=== Building Online x86_64 ISO ==="
        docker build --platform linux/amd64 \
            -f Dockerfile.iso-online \
            --target builder \
            -t ttyai/iso-builder:amd64 .
        extract_iso amd64 ttyai-x86_64.iso
    fi
}

build_offline() {
    if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "both" ]; then
        echo "=== Building Offline ARM64 ISO ==="
        docker build --platform linux/arm64 \
            -f Dockerfile.iso-offline \
            --target builder \
            -t ttyai/iso-builder:offline-arm64 .
        extract_iso offline-arm64 ttyai-offline-arm64.iso
    fi

    if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "both" ]; then
        echo "=== Building Offline x86_64 ISO ==="
        docker build --platform linux/amd64 \
            -f Dockerfile.iso-offline \
            --target builder \
            -t ttyai/iso-builder:offline-amd64 .
        extract_iso offline-amd64 ttyai-offline-x86_64.iso
    fi
}

case "$EDITION" in
    online)  build_online ;;
    offline) build_offline ;;
    all)     build_online; build_offline ;;
    *)
        echo "Usage: $0 [online|offline|all] [arm64|x86_64|both]"
        echo ""
        echo "  $0                    # all editions, both architectures"
        echo "  $0 online arm64       # online ARM64 only"
        echo "  $0 offline x86_64     # offline x86_64 only"
        exit 1
        ;;
esac

echo ""
echo "=== Done ==="
ls -lh "$DIST"/*.iso 2>/dev/null
