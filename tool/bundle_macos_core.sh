#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:-}"
if [ -z "$APP_BUNDLE" ]; then
    echo "::error::usage: bundle_macos_core.sh <app_bundle_path>"
    exit 1
fi

if [ ! -d "$APP_BUNDLE" ]; then
    echo "::error::app bundle not found at $APP_BUNDLE"
    ls -la "$(dirname "$APP_BUNDLE")" || true
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/core_versions.env"

version="$MIHOMO_VERSION"
amd_name="mihomo-darwin-amd64-$version.gz"
arm_name="mihomo-darwin-arm64-$version.gz"
amd_url="https://github.com/MetaCubeX/mihomo/releases/download/$version/$amd_name"
arm_url="https://github.com/MetaCubeX/mihomo/releases/download/$version/$arm_name"

echo "mihomo version: $version"
echo "amd64: $amd_url"
echo "arm64: $arm_url"

curl --fail --silent --show-error --location "$amd_url" -o mihomo-amd64.gz
curl --fail --silent --show-error --location "$arm_url" -o mihomo-arm64.gz

actual_amd=$(shasum -a 256 mihomo-amd64.gz | awk '{print $1}')
if [ "$actual_amd" != "$MIHOMO_DARWIN_AMD64_SHA256" ]; then
    echo "::error::mihomo darwin amd64 sha256 mismatch: actual=$actual_amd expected=$MIHOMO_DARWIN_AMD64_SHA256"
    exit 1
fi

actual_arm=$(shasum -a 256 mihomo-arm64.gz | awk '{print $1}')
if [ "$actual_arm" != "$MIHOMO_DARWIN_ARM64_SHA256" ]; then
    echo "::error::mihomo darwin arm64 sha256 mismatch: actual=$actual_arm expected=$MIHOMO_DARWIN_ARM64_SHA256"
    exit 1
fi

echo "mihomo darwin sha256 verified"

gunzip mihomo-amd64.gz
gunzip mihomo-arm64.gz

# Combine into a universal binary so the build runs on both Intel and Apple Silicon Macs.
lipo -create mihomo-amd64 mihomo-arm64 -output mihomo
chmod +x mihomo
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp mihomo "$APP_BUNDLE/Contents/Resources/mihomo"
lipo -info "$APP_BUNDLE/Contents/Resources/mihomo" || true

# ── geo databases ────────────────────────────────────────────────────
# mihomo needs these for GEOIP/GEOSITE rules. Download to a temp file in the
# destination dir, SHA-256 verify, then atomically replace — a partial download
# is never used. Hash blank in core_versions.env = print only (don't enforce).
GEO_BASE="https://github.com/MetaCubeX/meta-rules-dat/releases/download/${GEO_VERSION}"
RES="$APP_BUNDLE/Contents/Resources"

fetch_geo() {
    local name="$1" expected="$2" tmp actual
    tmp="$(mktemp "$RES/.${name}.XXXXXX")"
    echo "Downloading $name (${GEO_VERSION})"
    if ! curl --fail --silent --show-error --location "$GEO_BASE/$name" -o "$tmp"; then
        rm -f "$tmp"; echo "::error::download failed: $name" >&2; exit 1
    fi
    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"; echo "::error::empty download: $name" >&2; exit 1
    fi
    actual="$(shasum -a 256 "$tmp" | awk '{print $1}')"
    if [ -z "$expected" ]; then
        echo "  $name sha256 = $actual  (paste into core_versions.env to lock)"
    elif [ "$actual" != "$expected" ]; then
        rm -f "$tmp"
        echo "::error::$name sha256 mismatch: actual=$actual expected=$expected" >&2
        exit 1
    else
        echo "  $name sha256 verified"
    fi
    mv -f "$tmp" "$RES/$name"   # verified → atomic rename (same dir)
}

fetch_geo "country.mmdb" "${GEOIP_MMDB_SHA256:-}"
fetch_geo "geosite.dat"  "${GEOSITE_DAT_SHA256:-}"
echo "geo databases ready"

# Cleanup
rm -f mihomo mihomo-amd64 mihomo-arm64 mihomo-amd64.gz mihomo-arm64.gz
