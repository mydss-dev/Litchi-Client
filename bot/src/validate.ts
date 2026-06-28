import JSON5 from 'json5';

const reservedKeys = new Set([
  'app_id',
  'owner_tg_user_id',
  'payload_b64',
  'signature',
]);

const allowedTopLevelKeys = new Set([
  'app_name',
  'logo_url',
  'api_base_list',
  'api_prefix',
  'invite_url_base',
  'invite_base_url',
  'invite_url',
  'frontend_url',
  'site_url',
  'avatar_url',
  'update_version',
  'update_download_url',
  'update_changelog',
]);

export function parseAndValidateConfig(raw: string): Record<string, unknown> {
  const json = parseLooseConfig(raw);
  if (!json || typeof json !== 'object' || Array.isArray(json)) {
    throw new Error('配置内容必须是 JSON 对象或 config.js 里的 payload 对象。');
  }

  const payload = json as Record<string, unknown>;
  for (const key of Object.keys(payload)) {
    if (reservedKeys.has(key)) {
      throw new Error(`不要填写系统字段: ${key}`);
    }
    if (!allowedTopLevelKeys.has(key)) {
      throw new Error(`存在未知字段: ${key}`);
    }
  }

  requireString(payload, 'app_name', 1, 40);
  requireHttpsUrlList(payload);
  requireHttpsUrl(payload, 'logo_url');
  optionalPath(payload, 'api_prefix');
  optionalHttpsUrl(payload, 'invite_url_base');
  optionalHttpsUrl(payload, 'invite_base_url');
  optionalHttpsUrl(payload, 'invite_url');
  optionalHttpsUrl(payload, 'frontend_url');
  optionalHttpsUrl(payload, 'site_url');
  optionalHttpsUrl(payload, 'avatar_url');
  optionalString(payload, 'update_version', 0, 20);
  optionalUrl(payload, 'update_download_url');
  optionalString(payload, 'update_changelog', 0, 200);

  return payload;
}

/// Strips `//` line comments and `/* … */` block comments from a JSON-like
/// string so users can paste a documented config file directly into the bot.
function stripJsonComments(raw: string): string {
  let result = '';
  let inSingleLine = false;
  let inMultiLine = false;
  let inString = false;
  let stringQuote = '';
  let escaped = false;

  for (let i = 0; i < raw.length; i += 1) {
    const ch = raw[i];
    const next = raw[i + 1] ?? '';

    if (inSingleLine) {
      if (ch === '\n' || ch === '\r') {
        inSingleLine = false;
        result += ch;
      }
      continue;
    }

    if (inMultiLine) {
      if (ch === '*' && next === '/') {
        inMultiLine = false;
        i += 1; // skip '/'
      }
      continue;
    }

    if (inString) {
      result += ch;
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch === '\\') {
        escaped = true;
        continue;
      }
      if (ch === stringQuote) {
        inString = false;
        stringQuote = '';
      }
      continue;
    }

    // Not in a string — check for comment start.
    if (ch === '/' && next === '/') {
      inSingleLine = true;
      i += 1; // skip second '/'
      continue;
    }
    if (ch === '/' && next === '*') {
      inMultiLine = true;
      i += 1; // skip '*'
      continue;
    }

    result += ch;
    if (ch === '"' || ch === "'" || ch === '`') {
      inString = true;
      stringQuote = ch;
    }
  }

  return result;
}

export function parseLooseConfig(raw: string): unknown {
  const cleaned = stripJsonComments(stripCodeFence(raw)).trim();
  if (!cleaned) {
    throw new Error('配置内容为空，请发送 JSON 或 config.js 中的 payload 内容。');
  }

  try {
    return JSON.parse(cleaned) as unknown;
  } catch {
    // Fall back to object-literal parsing for config.js style input.
  }

  const objectLiteral = extractObjectLiteral(cleaned);

  try {
    // Parse the object literal WITHOUT executing it. JSON5 accepts the
    // config.js conveniences (unquoted keys, single quotes, trailing commas,
    // comments) but never evaluates expressions, function calls or template
    // strings — so a malicious payload pasted into the bot cannot run code on
    // the host that holds the Ed25519 signing key.
    const value = JSON5.parse(objectLiteral) as unknown;
    return JSON.parse(JSON.stringify(value)) as unknown;
  } catch (error) {
    throw new Error(
      [
        '配置解析失败。',
        '支持两种格式：',
        '1. 纯 JSON 对象',
        '2. config.js 里的 const payload = { ... }',
        error instanceof Error ? `详细错误: ${error.message}` : String(error),
      ].join('\n'),
    );
  }
}

function stripCodeFence(raw: string): string {
  const trimmed = raw.trim();
  const match = trimmed.match(/^```[a-zA-Z0-9_-]*\s*([\s\S]*?)\s*```$/);
  return match ? match[1] : trimmed;
}

function extractObjectLiteral(raw: string): string {
  const payloadMatch = raw.match(
    /(?:const|let|var)\s+payload\s*=\s*({[\s\S]*?})\s*;?(?:\s*console\.log[\s\S]*)?$/i,
  );
  if (payloadMatch) {
    return payloadMatch[1];
  }

  const moduleMatch = raw.match(/module\.exports\s*=\s*({[\s\S]*?})\s*;?\s*$/i);
  if (moduleMatch) {
    return moduleMatch[1];
  }

  const exportDefaultMatch = raw.match(/export\s+default\s+({[\s\S]*?})\s*;?\s*$/i);
  if (exportDefaultMatch) {
    return exportDefaultMatch[1];
  }

  const firstBrace = raw.indexOf('{');
  if (firstBrace === -1) {
    throw new Error('没有找到对象内容，请直接发送 JSON 或 config.js 的 payload。');
  }

  let depth = 0;
  let inString = false;
  let stringQuote = '';
  let escaped = false;

  for (let index = firstBrace; index < raw.length; index += 1) {
    const char = raw[index];

    if (inString) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char === '\\') {
        escaped = true;
        continue;
      }
      if (char === stringQuote) {
        inString = false;
        stringQuote = '';
      }
      continue;
    }

    if (char === '"' || char === "'" || char === '`') {
      inString = true;
      stringQuote = char;
      continue;
    }

    if (char === '{') {
      depth += 1;
    } else if (char === '}') {
      depth -= 1;
      if (depth === 0) {
        return raw.slice(firstBrace, index + 1);
      }
    }
  }

  throw new Error('对象大括号不完整，请检查 config 内容。');
}

function requireString(
  obj: Record<string, unknown>,
  key: string,
  min: number,
  max: number,
): void {
  const value = obj[key];
  if (typeof value !== 'string') {
    throw new Error(`${key} 必须是字符串。`);
  }

  const trimmed = value.trim();
  if (/[\u0000-\u001f\u007f]/.test(trimmed)) {
    throw new Error(`${key} 不能包含控制字符。`);
  }
  if (trimmed.length < min || trimmed.length > max) {
    throw new Error(`${key} 长度必须在 ${min}-${max} 之间。`);
  }
  obj[key] = trimmed;
}

function optionalString(
  obj: Record<string, unknown>,
  key: string,
  min: number,
  max: number,
): void {
  const value = obj[key];
  if (value === undefined) return;
  if (typeof value !== 'string') {
    throw new Error(`${key} 必须是字符串。`);
  }

  const trimmed = value.trim();
  if (/[\u0000-\u001f\u007f]/.test(trimmed)) {
    throw new Error(`${key} 不能包含控制字符。`);
  }
  if (trimmed.length < min || trimmed.length > max) {
    throw new Error(`${key} 长度必须在 ${min}-${max} 之间。`);
  }
  obj[key] = trimmed;
}

function requireHttpsUrlList(obj: Record<string, unknown>): void {
  const list = obj.api_base_list;
  if (!Array.isArray(list) || list.length === 0) {
    throw new Error('必须填写 api_base_list（至少一个 https 地址）。');
  }
  const urls = list.map((value) => assertHttpsUrl(String(value)));
  obj.api_base_list = urls;
}

function requireHttpsUrl(obj: Record<string, unknown>, key: string): void {
  const value = obj[key];
  if (typeof value !== 'string' || !value.trim()) {
    throw new Error(`${key} 必须填写 https URL。`);
  }
  obj[key] = assertHttpsUrl(value);
}

function optionalHttpsUrl(obj: Record<string, unknown>, key: string): void {
  const value = obj[key];
  if (value === undefined || value === '') return;
  if (typeof value !== 'string') {
    throw new Error(`${key} 必须是 URL 字符串。`);
  }
  obj[key] = assertHttpsUrl(value);
}

function assertHttpsUrl(raw: string): string {
  const value = raw.trim().replace(/\/+$/, '');
  const url = new URL(value);
  if (url.protocol !== 'https:' || !url.hostname) {
    throw new Error(`URL 必须是 https: ${raw}`);
  }
  return value;
}

function optionalPath(obj: Record<string, unknown>, key: string): void {
  const value = obj[key];
  if (value === undefined || value === '') return;
  if (typeof value !== 'string') {
    throw new Error(`${key} 必须是字符串。`);
  }

  const trimmed = value.trim();
  if (!trimmed.startsWith('/')) {
    throw new Error(`${key} 必须以 / 开头。`);
  }
  if (trimmed.length > 80) {
    throw new Error(`${key} 过长。`);
  }
  obj[key] = trimmed;
}

function optionalUrl(
  obj: Record<string, unknown>,
  key: string,
): void {
  const value = obj[key];
  if (value === undefined || value === '') return;
  if (typeof value !== 'string') {
    // Accept an object like {"windows":"...","macos":"..."}
    if (value !== null && typeof value === 'object') {
      const map = value as Record<string, unknown>;
      for (const url of Object.values(map)) {
        if (typeof url !== 'string' || !url.startsWith('https://')) {
          throw new Error(`${key} 里每个值都必须是 https URL。`);
        }
      }
      return;
    }
    throw new Error(`${key} 必须是字符串或按平台的对象 {"windows":"...",...}。`);
  }
  const trimmed = value.trim();
  if (!trimmed.startsWith('https://')) {
    throw new Error(`${key} 必须是 https URL。`);
  }
}
