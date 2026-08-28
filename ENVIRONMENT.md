# Environment Configuration

This document defines the deployment configuration required to build, sign, and publish Litchi Client.

The project does not store production URLs or signing keys in source code. Runtime configuration is injected by GitHub Actions from repository variables and secrets. Remote configuration and update manifests use independent Ed25519 trust roots.

## Configuration model

Only one CDN base URL is maintained:

```text
CDN_BASE_URL=https://cdn.example.com
```

The build and release workflows derive all public endpoints from this value:

```text
Remote configuration   https://cdn.example.com/config.json
Update manifest        https://cdn.example.com/update.json
Release packages       https://cdn.example.com/download/<filename>
```

The expected object layout in Cloudflare R2 is:

```text
/
├── config.json
├── update.json
└── download/
    ├── Litchi-Setup-<version>.exe
    ├── Litchi-<version>.apk
    └── Litchi-<version>.dmg
```

The `download` path is lowercase.

## Trust domains

Remote configuration and application updates are signed independently.

| Artifact | Signing key | Verification key |
|---|---|---|
| `config.json` | `REMOTE_CONFIG_PRIVATE_KEY` | `REMOTE_CONFIG_PUBLIC_KEY` |
| `update.json` | `UPDATE_PRIVATE_KEY` | `UPDATE_PUBLIC_KEY` |

The two keypairs must be generated independently. A Remote Config key must never be reused for update signing, and an Update key must never be accepted by the Remote Config verifier.

## GitHub repository variables

Configure repository variables under:

`Settings → Secrets and variables → Actions → Variables`

| Variable | Required | Description |
|---|---:|---|
| `CDN_BASE_URL` | Yes | Public HTTPS CDN origin. Do not append `config.json`, `update.json`, or `download`. |
| `REMOTE_CONFIG_PUBLIC_KEY` | Yes | Base64URL-encoded Ed25519 public key used to verify `config.json`. |
| `UPDATE_PUBLIC_KEY` | Yes | Base64URL-encoded Ed25519 public key used to verify `update.json`. |
| `REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY` | No | Previous Remote Config public key used only during key rotation. |
| `UPDATE_PREVIOUS_PUBLIC_KEY` | No | Previous Update public key used only during key rotation. |

For a new deployment, only the first three variables are required. Previous-key variables should remain unset until a key rotation is performed.

## GitHub repository secrets

Configure repository secrets under:

`Settings → Secrets and variables → Actions → Secrets`

| Secret | Required | Description |
|---|---:|---|
| `API_BASE` | Yes for tagged releases | Base URL of the panel API compiled into release builds. |
| `ANDROID_KEYSTORE_BASE64` | Yes for Android tagged releases | Base64-encoded Android signing keystore. |
| `ANDROID_KEYSTORE_PASSWORD` | Yes for Android tagged releases | Android keystore password. |
| `ANDROID_KEY_ALIAS` | Yes for Android tagged releases | Android signing key alias. |
| `ANDROID_KEY_PASSWORD` | Yes for Android tagged releases | Android signing key password. |
| `APP_NAME` | No | Application display name. Defaults to `Litchi`. |
| `LOGO_URL` | No | Optional branding asset URL. Built-in assets are used when omitted. |

Public Ed25519 keys must be stored as repository variables, not repository secrets.

## GitHub environments

The publish workflow separates signing credentials from upload credentials by using two GitHub Environments.

Create the following environments under:

`Settings → Environments`

### `release-signing`

Environment secret:

| Secret | Description |
|---|---|
| `UPDATE_PRIVATE_KEY` | Ed25519 private key used exclusively to sign `update.json`. |

This environment must not contain R2 credentials or the Remote Config private key.

### `release-upload`

Environment secrets:

| Secret | Description |
|---|---|
| `R2_ACCOUNT_ID` | Cloudflare account ID. |
| `R2_ACCESS_KEY_ID` | R2 API access key ID. |
| `R2_SECRET_ACCESS_KEY` | R2 API secret access key. |
| `R2_BUCKET` | R2 bucket name. |

This environment must not contain any signing private key.

## Remote Config private key

`REMOTE_CONFIG_PRIVATE_KEY` is not required by the current GitHub release workflow because `config.json` is maintained separately from application releases.

Store this private key offline or in a trusted secret-management system. It must not be committed to the repository or uploaded to the CDN.

## Generating signing keys

Install project dependencies first:

```bash
flutter pub get
```

### Remote Config keypair

Generate a dedicated Remote Config keypair:

```bash
dart run tool/sign_remote_config.dart generate
```

The command prints:

```text
PRIVATE_KEY=<base64url-private-key>
PUBLIC_KEY=<base64url-public-key>
```

Store the values as follows:

```text
PRIVATE_KEY → REMOTE_CONFIG_PRIVATE_KEY → offline secret storage
PUBLIC_KEY  → REMOTE_CONFIG_PUBLIC_KEY  → GitHub Repository Variable
```

### Update keypair

Generate a second, independent keypair:

```bash
dart run tool/sign_update_manifest.dart generate
```

Store the values as follows:

```text
PRIVATE_KEY → UPDATE_PRIVATE_KEY → release-signing Environment Secret
PUBLIC_KEY  → UPDATE_PUBLIC_KEY  → GitHub Repository Variable
```

Do not reuse either keypair across the two trust domains.

## Building configuration

The CI workflow derives the Remote Config URL from `CDN_BASE_URL` and injects the public configuration into Flutter builds with `--dart-define`.

For example, when:

```text
CDN_BASE_URL=https://cdn.example.com
```

CI derives:

```text
REMOTE_CONFIG_URL=https://cdn.example.com/config.json
```

The update service resolves `update.json` as a sibling of `config.json`, so no separate update-manifest URL variable is required.

The following values are intentionally not configured as independent GitHub variables or secrets:

```text
REMOTE_CONFIG_URL
DOWNLOAD_BASE_URL
UPDATE_MANIFEST_URL
```

## Creating `config.json`

Remote configuration is signed with the Remote Config keypair.

Given an unsigned JSON payload such as `config-payload.json`, create the signed envelope with:

```bash
dart run tool/sign_remote_config.dart sign \
  config-payload.json \
  <REMOTE_CONFIG_PRIVATE_KEY> \
  <REMOTE_CONFIG_PUBLIC_KEY> \
  > config.json
```

Alternatively, provide the keys through local environment variables and use:

```bash
dart run tool/sign_remote_config.dart sign-env config-payload.json > config.json
```

The resulting `config.json` may be published to the root of the CDN/R2 bucket:

```text
https://cdn.example.com/config.json
```

The private key must remain offline.

## Release workflow

Application releases use two workflows:

1. `.github/workflows/ci.yml` builds platform packages and creates the GitHub Release for a `v*` tag.
2. `.github/workflows/publish.yml` signs the update manifest and uploads release artifacts to R2.

The publish workflow is manually triggered with the release tag, for example:

```text
v1.2.3
```

### Signing stage

The `sign` job runs in the `release-signing` environment.

It:

- downloads `.exe`, `.apk`, and `.dmg` assets from the selected GitHub Release;
- computes package hashes and release metadata;
- signs `update.json` with `UPDATE_PRIVATE_KEY`;
- produces the signed release artifact for the upload stage.

The signing job does not receive R2 credentials.

### Upload stage

The `upload` job runs in the `release-upload` environment.

It uploads:

```text
/update.json
/download/<windows-package>.exe
/download/<android-package>.apk
/download/<macos-package>.dmg
```

Packages are uploaded before `update.json` so clients cannot observe a new manifest before the referenced package objects are available.

The upload job does not receive a signing private key.

## Release validation

Tagged releases use fail-closed configuration validation.

A `v*` release must provide:

```text
CDN_BASE_URL
REMOTE_CONFIG_PUBLIC_KEY
UPDATE_PUBLIC_KEY
API_BASE
```

Android tagged releases additionally require:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

`CDN_BASE_URL` must be an absolute HTTPS URL. The current public keys must decode to valid 32-byte Ed25519 public keys.

Before publishing a release, verify that CI completes successfully for the intended tag. Then run the `Publish` workflow and confirm that both jobs complete successfully:

```text
sign    success
upload  success
```

Finally, verify that the CDN exposes:

```text
/config.json
/update.json
/download/<release-files>
```

## Key rotation

Key rotation is optional and is not required for an initial deployment.

When rotating a trust root, the previous public key may temporarily be supplied through:

```text
REMOTE_CONFIG_PREVIOUS_PUBLIC_KEY
UPDATE_PREVIOUS_PUBLIC_KEY
```

Only the previous key from the same trust domain may be accepted. Remote Config keys and Update keys must remain isolated throughout rotation.

After the migration window is complete, remove the corresponding previous-key variable.

## Security requirements

The following requirements are part of the release architecture:

- production URLs are not hard-coded in source files;
- private signing keys are never committed to the repository;
- public verification keys are provided through GitHub repository variables;
- `config.json` and `update.json` use independent Ed25519 keypairs;
- the update signing job has no R2 write credentials;
- the R2 upload job has no signing private key;
- GitHub Actions references remain pinned to full commit SHAs;
- release configuration fails closed when mandatory values are missing or invalid.

These boundaries should be preserved when modifying CI, signing, or deployment tooling.
