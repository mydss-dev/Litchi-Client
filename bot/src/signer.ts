import nacl from 'tweetnacl';

import { b64url, b64urlDecode } from './codec.js';

export type KeyPairB64 = {
  privateKey: string;
  publicKey: string;
};

export type ReleaseMetadata = {
  platform: string;
  version: string;
  downloadUrl: string;
  sha256: string;
};

export function generateKeyPair(): KeyPairB64 {
  const pair = nacl.sign.keyPair();
  return {
    privateKey: b64url(Buffer.from(pair.secretKey.slice(0, 32))),
    publicKey: b64url(Buffer.from(pair.publicKey)),
  };
}

export function signConfigPayload(
  payload: Record<string, unknown>,
  privateKeyB64: string,
): { payload_b64: string; signature: string } {
  const seed = b64urlDecode(privateKeyB64);
  if (seed.length !== 32) {
    throw new Error('PRIVATE_KEY must be a 32-byte base64url Ed25519 seed');
  }

  const pair = nacl.sign.keyPair.fromSeed(seed);
  const payloadBytes = Buffer.from(JSON.stringify(payload), 'utf8');
  const signature = nacl.sign.detached(payloadBytes, pair.secretKey);

  return {
    payload_b64: b64url(payloadBytes),
    signature: b64url(Buffer.from(signature)),
  };
}

export function verifyConfigPayload(
  signedConfig: string,
  publicKeyB64: string,
): Record<string, unknown> {
  const wrapper = JSON.parse(signedConfig) as {
    payload_b64?: unknown;
    signature?: unknown;
  };
  if (
    typeof wrapper.payload_b64 !== 'string' ||
    typeof wrapper.signature !== 'string'
  ) {
    throw new Error('保存的签名配置格式无效，请重新执行 /config。');
  }

  const publicKey = b64urlDecode(publicKeyB64);
  const payloadBytes = b64urlDecode(wrapper.payload_b64);
  const signature = b64urlDecode(wrapper.signature);
  if (
    publicKey.length !== 32 ||
    signature.length !== 64 ||
    !nacl.sign.detached.verify(payloadBytes, signature, publicKey)
  ) {
    throw new Error('保存的签名配置验签失败，请重新执行 /config。');
  }

  const payload = JSON.parse(payloadBytes.toString('utf8')) as unknown;
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new Error('保存的签名配置内容无效，请重新执行 /config。');
  }
  return payload as Record<string, unknown>;
}

export function withReleaseMetadata(
  current: Record<string, unknown>,
  releases: ReleaseMetadata[],
): Record<string, unknown> {
  const payload = { ...current };
  delete payload.config_version;
  if (releases.length === 0) {
    throw new Error('没有可写入配置的安装包信息。');
  }
  const version = releases[0].version;
  if (releases.some((release) => release.version !== version)) {
    throw new Error('同一批发布包的版本号不一致。');
  }

  const sameRelease = payload.update_version === version;
  const urls = sameRelease ? stringMap(payload.update_download_url) : {};
  const hashes = sameRelease ? stringMap(payload.update_sha256) : {};
  for (const release of releases) {
    urls[release.platform] = release.downloadUrl;
    hashes[release.platform] = release.sha256;
  }

  payload.update_version = version;
  payload.update_download_url = urls;
  payload.update_sha256 = hashes;
  return payload;
}

export function withPreservedUpdateMetadata(
  input: Record<string, unknown>,
  _previous?: Record<string, unknown>,
): Record<string, unknown> {
  const payload = { ...input };
  delete payload.config_version;
  delete payload.update_manifest_url;
  delete payload.update_version;
  delete payload.update_download_url;
  delete payload.update_sha256;
  delete payload.update_changelog;
  return payload;
}

export function updateManifestUrl(remoteConfigUrl: string): string {
  const url = new URL(remoteConfigUrl);
  url.pathname = url.pathname.replace(/\/[^/]*$/, '/update.json');
  return url.toString();
}

export function withUpdateManifestUrl(
  payload: Record<string, unknown>,
  remoteConfigUrl: string,
): Record<string, unknown> {
  return {
    ...payload,
    update_manifest_url: updateManifestUrl(remoteConfigUrl),
  };
}

function stringMap(value: unknown): Record<string, string> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value).filter(
      (entry): entry is [string, string] => typeof entry[1] === 'string',
    ),
  );
}

export function withConfigVersion(
  payload: Record<string, unknown>,
  configVersion: number,
): Record<string, unknown> {
  if (!Number.isSafeInteger(configVersion) || configVersion <= 0) {
    throw new Error('config_version must be a positive safe integer');
  }
  return { ...payload, config_version: configVersion };
}
