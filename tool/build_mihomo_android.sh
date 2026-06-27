#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/core/mihomo"
JNI="$ROOT/android/app/src/main/jniLibs"
INCLUDES="$ROOT/android/app/src/main/cpp/includes"
NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"

if [[ -z "$NDK" || ! -d "$NDK" ]]; then
  echo "ANDROID_NDK_HOME or ANDROID_NDK_ROOT must point to an installed NDK" >&2
  exit 1
fi

PREBUILT="$(find "$NDK/toolchains/llvm/prebuilt" -mindepth 1 -maxdepth 1 -type d | head -1)"
BIN="$PREBUILT/bin"

build_one() {
  local abi="$1" arch="$2" cc_name="$3"
  local out="$JNI/$abi"
  local include="$INCLUDES/$abi"
  mkdir -p "$out" "$include"
  (
    cd "$CORE"
    GOOS=android GOARCH="$arch" GOARM="${4:-}" CGO_ENABLED=1 CC="$BIN/$cc_name" \
      go build -tags "with_gvisor,cmfa" -trimpath \
        -ldflags="-s -w -X main.version=v1.19.27" \
        -buildmode=c-shared -o "$out/liblitchi_mihomo.so" .
  )
  cp "$out/liblitchi_mihomo.h" "$include/liblitchi_mihomo.h"
  cp "$CORE/bridge.h" "$include/bridge.h"
}

build_one arm64-v8a arm64 aarch64-linux-android21-clang
build_one armeabi-v7a arm armv7a-linux-androideabi21-clang 7
build_one x86_64 amd64 x86_64-linux-android21-clang

echo "mihomo Android libraries are ready"
