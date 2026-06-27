#!/bin/bash
# Build Litchi Client with branding from config.json.
#
# Usage:
#   ./tool/build_from_config.sh windows   (or macos, android)
#
# Reads app_name, logo_url from config.json and passes them as --dart-define
# flags automatically. No more manual dart-define typing.

set -euo pipefail

PLATFORM="${1:-windows}"
CONFIG="config.json"

if [ ! -f "$CONFIG" ]; then
  echo "ERROR: $CONFIG not found. Create it first (see config.json template)."
  exit 1
fi

# Extract values from config.json using jq
APP_NAME=$(jq -r '.app_name // empty' "$CONFIG")
LOGO_URL=$(jq -r '.logo_url // empty' "$CONFIG")
API_BASE=$(jq -r '.api_base_list[0] // empty' "$CONFIG")
VERSION=$(jq -r '.update_version // empty' "$CONFIG")

# Build the dart-define flags
FLAGS=()
[ -n "$APP_NAME" ] && FLAGS+=("--dart-define=APP_NAME=$APP_NAME")
[ -n "$LOGO_URL" ] && FLAGS+=("--dart-define=LOGO_URL=$LOGO_URL")
[ -n "$API_BASE" ] && FLAGS+=("--dart-define=API_BASE=$API_BASE")
[ -n "$VERSION" ]  && FLAGS+=("--dart-define=APP_VERSION=$VERSION")

echo "==> Building for $PLATFORM"
echo "    Name:   ${APP_NAME:-'(not set)'}"
echo "    Logo:   ${LOGO_URL:-'(not set)'}"
echo "    API:    ${API_BASE:-'(not set)'}"
echo "    Version: ${VERSION:-'(not set)'}"
echo ""

case "$PLATFORM" in
  windows)
    flutter build windows --release "${FLAGS[@]}"
    echo ""
    echo "==> Done. Output: build/windows/x64/runner/Release/"
    ;;
  macos)
    flutter build macos --release "${FLAGS[@]}"
    echo ""
    echo "==> Done. Output: build/macos/Build/Products/Release/"
    ;;
  android)
    flutter build apk --release "${FLAGS[@]}"
    echo ""
    echo "==> Done. Output: build/app/outputs/flutter-apk/"
    ;;
  *)
    echo "ERROR: Unknown platform '$PLATFORM'. Use: windows, macos, android"
    exit 1
    ;;
esac
