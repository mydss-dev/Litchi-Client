#!/usr/bin/env bash
set -euo pipefail

REF="${1:-${LIBBOX_REF:-v1.13.13}}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORK_DIR="${LIBBOX_WORK_DIR:-$ROOT/build/sing-box-src}"
LIBS="$ROOT/android/app/libs"

command -v git >/dev/null || { echo "Missing required command: git" >&2; exit 1; }
command -v go >/dev/null || { echo "Missing required command: go" >&2; exit 1; }

if [[ -z "${ANDROID_HOME:-}" && -z "${ANDROID_SDK_ROOT:-}" ]]; then
  echo "ANDROID_HOME or ANDROID_SDK_ROOT must be set" >&2
  exit 1
fi

if [[ ! -d "$WORK_DIR/.git" ]]; then
  git clone --depth 1 --branch "$REF" https://github.com/SagerNet/sing-box.git "$WORK_DIR"
else
  git -C "$WORK_DIR" fetch --depth 1 origin "$REF"
  git -C "$WORK_DIR" checkout FETCH_HEAD
fi

echo "Building sing-box libbox from ref $REF ($(git -C "$WORK_DIR" rev-parse HEAD))"

make -C "$WORK_DIR" lib_install
make -C "$WORK_DIR" lib_android

aar="$(find "$WORK_DIR" -name libbox.aar -print -quit)"
if [[ -z "$aar" ]]; then
  echo "libbox.aar was not produced by the sing-box build" >&2
  exit 1
fi

mkdir -p "$LIBS"
cp "$aar" "$LIBS/libbox.aar"

# Deliberately NOT copying libbox-legacy.aar: it duplicates libbox.aar's
# io.nekohasekai.libbox classes and arm64-v8a/libbox.so, which breaks
# mergeReleaseNativeLibs. The modern libbox.aar covers our targets.

echo "Copied libbox.aar to android/app/libs"
