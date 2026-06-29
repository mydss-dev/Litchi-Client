#!/usr/bin/env bash
# Refreshes the VENDORED geo databases and updates core_versions.env.
#
# Upstream only publishes a rolling "latest" release, so this always fetches the
# newest build. Reproducibility comes from committing the bytes, not from a tag.
#
#   Usage:  bash tool/update_geo.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GEO_DIR="$REPO_ROOT/runtime/geo"
ENV_FILE="$SCRIPT_DIR/core_versions.env"
mkdir -p "$GEO_DIR"

base="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest"
country_tmp="$(mktemp "$GEO_DIR/.country.mmdb.XXXXXX.part")"
geosite_tmp="$(mktemp "$GEO_DIR/.geosite.dat.XXXXXX.part")"
env_tmp=""
cleanup() {
    rm -f "$country_tmp" "$geosite_tmp"
    if [ -n "$env_tmp" ]; then rm -f "$env_tmp"; fi
}
trap cleanup EXIT

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

echo "Downloading country.mmdb ..."
curl --fail --silent --show-error --location "$base/country.mmdb" -o "$country_tmp"
echo "Downloading geosite.dat ..."
curl --fail --silent --show-error --location "$base/geosite.dat" -o "$geosite_tmp"

if [ ! -s "$country_tmp" ] || [ ! -s "$geosite_tmp" ]; then
    echo "error: downloaded geo file is empty" >&2
    exit 1
fi

country_sha="$(sha256_of "$country_tmp")"
geosite_sha="$(sha256_of "$geosite_tmp")"
snapshot="$(date -u +%Y-%m-%d)"

# Only replace the committed snapshots after both downloads succeed.
mv -f "$country_tmp" "$GEO_DIR/country.mmdb"
mv -f "$geosite_tmp" "$GEO_DIR/geosite.dat"

env_tmp="$(mktemp "$SCRIPT_DIR/.core_versions.env.XXXXXX.tmp")"
awk \
    -v snapshot="$snapshot" \
    -v country_sha="$country_sha" \
    -v geosite_sha="$geosite_sha" \
    'BEGIN { snapshot_set=country_set=geosite_set=0 }
     /^GEO_SNAPSHOT=/ {
       print "GEO_SNAPSHOT=" snapshot; snapshot_set=1; next
     }
     /^GEOIP_MMDB_SHA256=/ {
       print "GEOIP_MMDB_SHA256=" country_sha; country_set=1; next
     }
     /^GEOSITE_DAT_SHA256=/ {
       print "GEOSITE_DAT_SHA256=" geosite_sha; geosite_set=1; next
     }
     { print }
     END {
       if (!snapshot_set) print "GEO_SNAPSHOT=" snapshot
       if (!country_set) print "GEOIP_MMDB_SHA256=" country_sha
       if (!geosite_set) print "GEOSITE_DAT_SHA256=" geosite_sha
     }' "$ENV_FILE" > "$env_tmp"
mv -f "$env_tmp" "$ENV_FILE"

echo
echo "Geo snapshot updated: $snapshot"
echo "GEOIP_MMDB_SHA256=$country_sha"
echo "GEOSITE_DAT_SHA256=$geosite_sha"
echo "Updated runtime/geo and tool/core_versions.env. Commit both."
