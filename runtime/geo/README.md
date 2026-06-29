# Vendored geo databases

These two files are loaded by the mihomo core to evaluate `GEOIP` / `GEOSITE`
rules (the panel's Clash config ends with `GEOIP,CN,DIRECT`):

- `country.mmdb`  — GeoIP database (required by `GEOIP,CN`)
- `geosite.dat`   — GeoSite database (only needed if a rule uses `GEOSITE,...`)

They are **committed to the repo** (not downloaded at build time) because
upstream MetaCubeX/meta-rules-dat only publishes a rolling `latest` tag with no
immutable dated tag to pin. Vendoring makes builds reproducible, integrity-
checked, and independent of upstream availability.

## Track with Git LFS (one-time)

```bash
git lfs install
git lfs track "runtime/geo/*.mmdb" "runtime/geo/*.dat"
git add .gitattributes
```

## Add / refresh the files

```bash
# Downloads both files, updates their SHA-256 values in core_versions.env,
# and bumps GEO_SNAPSHOT automatically.
bash tool/update_geo.sh          # macOS / Linux
#   or:  powershell -File tool\update_geo.ps1   (Windows)

# Then commit the updated snapshot and metadata:
git add runtime/geo/country.mmdb runtime/geo/geosite.dat tool/core_versions.env
git commit -m "chore(geo): update vendored geo databases"
```

The build copies these into each platform's bundle and verifies the SHA-256 in
`tool/core_versions.env`; a mismatch (e.g. Git LFS not pulled) fails the build.
