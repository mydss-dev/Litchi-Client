#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:-}"
if [[ -z "$APP_BUNDLE" || ! -d "$APP_BUNDLE" ]]; then
  echo "::error::usage: bundle_macos_singbox.sh <app_bundle_path>" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/core/singbox"
VERSION="$(sed -n 's/^SING_BOX_VERSION=v\{0,1\}//p' "$ROOT/tool/core_versions.env" | head -n 1)"
TAGS="with_clash_api,with_quic,with_utls,with_wireguard"
BUILD_DIR="$ROOT/build/singbox-macos"
FRAMEWORKS="$APP_BUNDLE/Contents/Frameworks"
mkdir -p "$BUILD_DIR" "$FRAMEWORKS"

build_arch() {
  local go_arch="$1"
  local clang_arch

  case "$go_arch" in
    amd64) clang_arch="x86_64" ;;
    arm64) clang_arch="arm64" ;;
    *)
      echo "::error::unsupported macOS architecture: $go_arch" >&2
      exit 1
      ;;
  esac

  CGO_ENABLED=1 GOOS=darwin GOARCH="$go_arch" \
    CGO_CFLAGS="-arch $clang_arch" CGO_LDFLAGS="-arch $clang_arch" \
    go build -C "$SOURCE" -trimpath -tags "$TAGS" -buildmode=c-shared \
      -ldflags "-s -w -X github.com/sagernet/sing-box/constant.Version=$VERSION" \
      -o "$BUILD_DIR/liblitchi_singbox-$go_arch.dylib" .
}

go mod download -C "$SOURCE"
build_arch amd64
build_arch arm64
lipo -create \
  "$BUILD_DIR/liblitchi_singbox-amd64.dylib" \
  "$BUILD_DIR/liblitchi_singbox-arm64.dylib" \
  -output "$FRAMEWORKS/liblitchi_singbox.dylib"
install_name_tool -id @rpath/liblitchi_singbox.dylib \
  "$FRAMEWORKS/liblitchi_singbox.dylib"
lipo -info "$FRAMEWORKS/liblitchi_singbox.dylib"

echo "sing-box universal dylib bundled into $FRAMEWORKS"
