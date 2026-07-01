import crypto from 'node:crypto';

import { env } from './config.js';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12; // 96 bits, standard for GCM
const TAG_LENGTH = 16; // 128 bits, appended to ciphertext

function masterKey(): Buffer {
  const hex = env.keyEncryptionKey;
  if (!hex) {
    throw new Error(
      'KEY_ENCRYPTION_KEY env var is required. Generate with: openssl rand -hex 32',
    );
  }
  const key = Buffer.from(hex, 'hex');
  if (key.length !== 32) {
    throw new Error('KEY_ENCRYPTION_KEY must be 32 bytes (64 hex chars)');
  }
  return key;
}

/**
 * Encrypts a plaintext private key for storage.
 *
 * Format: iv:tag:ciphertext  (all hex-encoded, colon-separated)
 * The iv is randomly generated per encryption so two identical plaintexts
 * produce different ciphertexts.
 */
export function encryptKey(plaintext: string): string {
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, masterKey(), iv);
  const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('hex')}:${tag.toString('hex')}:${encrypted.toString('hex')}`;
}

/**
 * Decrypts a ciphertext produced by {@link encryptKey}.
 *
 * Returns the original plaintext, or the input unchanged if it does not
 * match the encryption format (legacy plaintext compatibility).
 */
export function decryptKey(ciphertext: string): string {
  const parts = ciphertext.split(':');
  if (parts.length !== 3) {
    // Legacy plaintext — was stored before encryption was introduced.
    return ciphertext;
  }
  try {
    const iv = Buffer.from(parts[0], 'hex');
    const tag = Buffer.from(parts[1], 'hex');
    const encrypted = Buffer.from(parts[2], 'hex');
    const decipher = crypto.createDecipheriv(ALGORITHM, masterKey(), iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
  } catch {
    throw new Error(
      'Stored signing key cannot be decrypted. Check KEY_ENCRYPTION_KEY before continuing.',
    );
  }
}
