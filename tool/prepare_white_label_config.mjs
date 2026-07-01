import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const MAX_CONFIG_BYTES = 1024 * 1024;
const ED25519_SPKI_PREFIX = Buffer.from('302a300506032b6570032100', 'hex');

function requiredEnv(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing ${name}`);
  return value;
}

function decodeBase64Url(value, label) {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new Error(`${label} is not valid base64url`);
  }
  return Buffer.from(value, 'base64url');
}

function cleanText(value, label, maxLength) {
  if (typeof value !== 'string') throw new Error(`${label} must be a string`);
  const cleaned = value.trim();
  if (!cleaned || cleaned.length > maxLength || /[\r\n\0]/.test(cleaned)) {
    throw new Error(`${label} is empty, too long, or contains control characters`);
  }
  return cleaned;
}

function httpsUrl(value, label) {
  const cleaned = cleanText(value, label, 500);
  const parsed = new URL(cleaned);
  if (parsed.protocol !== 'https:' || !parsed.hostname) {
    throw new Error(`${label} must be an https URL`);
  }
  return parsed.toString();
}

function tenantSegment(appId) {
  let segment = appId.toLowerCase().replace(/[^a-z0-9_]/g, '_');
  if (!/^[a-z]/.test(segment)) segment = `app_${segment}`;
  return segment.slice(0, 50);
}

function packageFileName(appName, appId) {
  return windowsFileBaseName(appName, appId);
}

export function windowsFileBaseName(appName, appId) {
  let cleaned = appName
    .replace(/[<>:"/\\|?*\u0000-\u001f]/g, '_')
    .replace(/\s+/g, ' ')
    .replace(/[. ]+$/g, '')
    .trim();
  cleaned = Array.from(cleaned).slice(0, 60).join('').replace(/[. ]+$/g, '');
  if (/^(con|prn|aux|nul|com[1-9]|lpt[1-9])$/i.test(cleaned)) {
    cleaned += '-App';
  }
  if (cleaned) return cleaned;
  return 'Client-App';
}

function writeOutput(name, value) {
  if (/[\r\n\0]/.test(value)) throw new Error(`Unsafe output value for ${name}`);
  fs.appendFileSync(process.env.GITHUB_OUTPUT, `${name}=${value}\n`);
}

export function verifySignedPayload(wrapper, verifier) {
  if (
    !wrapper ||
    typeof wrapper !== 'object' ||
    typeof wrapper.payload_b64 !== 'string' ||
    typeof wrapper.signature !== 'string'
  ) {
    throw new Error('OSS config must be an Ed25519-signed config wrapper');
  }

  const payloadBytes = decodeBase64Url(wrapper.payload_b64, 'payload_b64');
  const signature = decodeBase64Url(wrapper.signature, 'signature');
  const publicKeyBytes = decodeBase64Url(verifier, 'REMOTE_CONFIG_VERIFIER');
  if (publicKeyBytes.length !== 32 || signature.length !== 64) {
    throw new Error('Invalid Ed25519 public key or signature length');
  }

  const publicKey = crypto.createPublicKey({
    key: Buffer.concat([ED25519_SPKI_PREFIX, publicKeyBytes]),
    format: 'der',
    type: 'spki',
  });
  if (!crypto.verify(null, payloadBytes, publicKey, signature)) {
    throw new Error('OSS config signature verification failed');
  }

  return JSON.parse(payloadBytes.toString('utf8'));
}

async function main() {
  const configUrl = httpsUrl(requiredEnv('REMOTE_CONFIG_URL'), 'REMOTE_CONFIG_URL');
  const verifier = requiredEnv('REMOTE_CONFIG_VERIFIER');
  // Public identity is safe for TUN names and artifact URLs. Native identity
  // remains stable for in-place upgrades of already-issued applications.
  const publicAppId = cleanText(requiredEnv('TENANT_ID'), 'TENANT_ID', 80);
  const nativeAppId = cleanText(
    requiredEnv('NATIVE_APP_ID'),
    'NATIVE_APP_ID',
    80,
  );
  const version = cleanText(requiredEnv('BUILD_VERSION'), 'BUILD_VERSION', 30);
  if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(version)) {
    throw new Error('BUILD_VERSION must be a semantic version such as 1.2.7');
  }

  const inlineConfig = process.env.SIGNED_CONFIG_B64?.trim() ?? '';
  let body;
  if (inlineConfig) {
    if (!/^[A-Za-z0-9+/]+={0,2}$/.test(inlineConfig)) {
      throw new Error('Inline signed config is not valid base64');
    }
    body = Buffer.from(inlineConfig, 'base64').toString('utf8');
  } else {
    // Compatibility fallback for builds dispatched before the bot started
    // storing signed configs locally.
    const response = await fetch(configUrl, {
      headers: { Accept: 'application/json' },
      redirect: 'follow',
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) {
      throw new Error(`Config download failed: HTTP ${response.status}`);
    }
    httpsUrl(response.url, 'Final config URL');
    const contentLength = Number(response.headers.get('content-length') ?? 0);
    if (contentLength > MAX_CONFIG_BYTES) throw new Error('Config file is too large');
    body = await response.text();
  }
  if (Buffer.byteLength(body) > MAX_CONFIG_BYTES) throw new Error('Config file is too large');

  const wrapper = JSON.parse(body);
  const payload = verifySignedPayload(wrapper, verifier);
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new Error('Signed config payload must be an object');
  }

  const appName = cleanText(payload.app_name, 'app_name', 40);
  if (!Array.isArray(payload.api_base_list) || payload.api_base_list.length === 0) {
    throw new Error('api_base_list must contain at least one URL');
  }
  const apiBase = httpsUrl(payload.api_base_list[0], 'api_base_list[0]');
  const logoUrl = httpsUrl(payload.logo_url, 'logo_url');

  const segment = tenantSegment(nativeAppId);
  const [major, minor, patch] = version.split(/[.+-]/, 3).map(Number);
  const versionCode = major * 1_000_000 + minor * 1_000 + patch;
  if (!Number.isSafeInteger(versionCode) || versionCode <= 0 || versionCode > 2_100_000_000) {
    throw new Error('Version is outside the supported Android versionCode range');
  }

  const configPath = path.join(process.env.RUNNER_TEMP || os.tmpdir(), 'litchi-tenant-config.json');
  fs.writeFileSync(configPath, JSON.stringify(payload, null, 2), 'utf8');

  writeOutput('app_name', appName);
  writeOutput('config_path', configPath);
  writeOutput('package_name', packageFileName(appName, publicAppId));
  writeOutput(
    'windows_exe_name',
    `${windowsFileBaseName(appName, publicAppId)}.exe`,
  );
  writeOutput('logo_url', logoUrl);
  writeOutput('api_base', apiBase);
  writeOutput('android_application_id', `com.litchi.whitelabel.${segment}`);
  writeOutput('macos_bundle_id', `com.litchi.whitelabel.${segment.replaceAll('_', '-')}`);
  writeOutput('version_code', String(versionCode));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}
