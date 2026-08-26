#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/core/singbox"
TARGET="${1:-$(go env GOOS)}"
ARCH="${2:-$(go env GOARCH)}"
OUTPUT="$ROOT/runtime/singbox/$TARGET-$ARCH"
mkdir -p "$OUTPUT"
VERSION="$(sed -n 's/^SING_BOX_VERSION=v\{0,1\}//p' "$ROOT/tool/core_versions.env" | head -n 1)"
if [[ -z "$VERSION" ]]; then
  echo "SING_BOX_VERSION is missing from tool/core_versions.env" >&2
  exit 1
fi

case "$TARGET" in
  windows) EXT=".dll" ;;
  darwin) EXT=".dylib" ;;
  *) EXT=".so" ;;
esac

cd "$SOURCE"
go mod download
CGO_ENABLED=1 GOOS="$TARGET" GOARCH="$ARCH" go build \
  -trimpath \
  -tags "with_clash_api,with_quic,with_utls,with_wireguard" \
  -buildmode=c-shared \
  -ldflags "-s -w -X github.com/sagernet/sing-box/constant.Version=$VERSION-litchi" \
  -o "$OUTPUT/litchi_singbox$EXT" .

echo "sing-box desktop library ready: $OUTPUT/litchi_singbox$EXT"
