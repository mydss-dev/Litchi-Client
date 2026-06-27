import nacl from 'tweetnacl';

import { b64url, b64urlDecode } from './codec.js';

export type KeyPairB64 = {
  privateKey: string;
  publicKey: string;
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
