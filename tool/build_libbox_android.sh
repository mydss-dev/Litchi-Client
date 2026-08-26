#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
versions="$root/tool/core_versions.env"
ref=${LIBBOX_REF:-$(sed -n 's/^SING_BOX_VERSION=//p' "$versions" | head -n 1)}
expected=$(sed -n 's/^SING_BOX_COMMIT=//p' "$versions" | head -n 1)
work=${LIBBOX_WORK_DIR:-"$root/build/sing-box-src"}
for command in git go java make; do
  command -v "$command" >/dev/null || { echo "Missing required command: $command" >&2; exit 1; }
done
: "${ANDROID_HOME:=${ANDROID_SDK_ROOT:-}}"
test -n "$ANDROID_HOME" || { echo "ANDROID_HOME or ANDROID_SDK_ROOT must be set" >&2; exit 1; }
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME"
if [[ -z ${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}} ]]; then
  ndk=$(find "$ANDROID_HOME/ndk" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)
  test -n "$ndk" || { echo "Android NDK is not installed" >&2; exit 1; }
  export ANDROID_NDK_HOME="$ndk" ANDROID_NDK_ROOT="$ndk"
fi
if [[ ! -d "$work/.git" ]]; then
  git clone --depth 1 --branch "$ref" https://github.com/SagerNet/sing-box.git "$work"
else
  git -C "$work" fetch --depth 1 origin "$ref"
  git -C "$work" checkout --detach FETCH_HEAD
fi
resolved=$(git -C "$work" rev-parse HEAD)
[[ "$resolved" == "$expected" ]] || { echo "sing-box commit mismatch: resolved=$resolved expected=$expected" >&2; exit 1; }
export PATH="$(go env GOPATH)/bin:$PATH"
make -C "$work" lib_install
make -C "$work" lib_android
aar=$(find "$work" -name libbox.aar -type f | head -n 1)
test -n "$aar" || { echo "libbox.aar was not produced" >&2; exit 1; }
mkdir -p "$root/android/app/libs"
cp "$aar" "$root/android/app/libs/libbox.aar"
echo "Copied libbox.aar to android/app/libs"
