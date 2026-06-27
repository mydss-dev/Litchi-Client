export function b64url(bytes: Buffer | Uint8Array): string {
  return Buffer.from(bytes)
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}

export function b64urlDecode(raw: string): Buffer {
  const normalized = raw.trim().replaceAll('-', '+').replaceAll('_', '/');
  const padded = normalized.padEnd(
    normalized.length + ((4 - normalized.length % 4) % 4),
    '=',
  );
  return Buffer.from(padded, 'base64');
}
