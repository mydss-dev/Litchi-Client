import 'dotenv/config';

export const env = {
  botToken: process.env.BOT_TOKEN ?? '',
  botAdmins: parseAdmins(process.env.BOT_ADMINS ?? ''),
  githubToken: process.env.GITHUB_TOKEN ?? '',
  githubRepo: process.env.GITHUB_REPO ?? 'mydss-dev/Litchi-Client',
  githubRef: process.env.GITHUB_REF ?? 'main',
  githubWorkflowId: process.env.GITHUB_WORKFLOW_ID ?? 'white-label-build.yml',
  buildVersion: process.env.BUILD_VERSION ?? '',
  downloadBaseUrl: normalizeBaseUrl(process.env.DOWNLOAD_BASE_URL ?? ''),
  dbPath: process.env.DB_PATH ?? './data/bot.sqlite',
  keyEncryptionKey: process.env.KEY_ENCRYPTION_KEY ?? '',
  buildRateLimit: {
    maxBuilds: Number(process.env.BUILD_RATE_LIMIT_MAX ?? '2'),
    windowHours: Number(process.env.BUILD_RATE_LIMIT_HOURS ?? '24'),
  },
};

function normalizeBaseUrl(raw: string): string {
  const value = raw.trim().replace(/\/+$/, '');
  if (!value) return '';
  const parsed = new URL(value);
  if (parsed.protocol !== 'https:' || !parsed.hostname || parsed.search || parsed.hash) {
    throw new Error('DOWNLOAD_BASE_URL must be an https URL without query or hash');
  }
  return value;
}

function parseAdmins(raw: string): Set<number> {
  return new Set(
    raw
      .split(',')
      .map((v) => Number(v.trim()))
      .filter((v) => Number.isFinite(v) && v > 0),
  );
}

export function requireBotToken(): string {
  if (!env.botToken) throw new Error('Missing BOT_TOKEN');
  return env.botToken;
}

export function requireAdminConfig(): void {
  if (env.botAdmins.size === 0) {
    throw new Error('BOT_ADMINS must contain at least one Telegram user id');
  }
  if (!env.githubToken) throw new Error('Missing GITHUB_TOKEN');
  repoParts();
  if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(env.buildVersion)) {
    throw new Error('BUILD_VERSION must be a semantic version such as 1.2.7');
  }
  if (!env.downloadBaseUrl) {
    throw new Error('Missing DOWNLOAD_BASE_URL');
  }
  if (!/^[a-fA-F0-9]{64}$/.test(env.keyEncryptionKey)) {
    throw new Error('KEY_ENCRYPTION_KEY must be 64 hexadecimal characters');
  }
  if (
    !Number.isSafeInteger(env.buildRateLimit.maxBuilds) ||
    env.buildRateLimit.maxBuilds <= 0 ||
    !Number.isFinite(env.buildRateLimit.windowHours) ||
    env.buildRateLimit.windowHours <= 0
  ) {
    throw new Error('Build rate limit values must be positive numbers');
  }
}

export function isAdmin(userId?: number): boolean {
  if (!userId) return false;
  return env.botAdmins.has(userId);
}

export function repoParts(): { owner: string; repo: string } {
  const [owner, repo] = env.githubRepo.split('/');
  if (!owner || !repo) throw new Error('GITHUB_REPO must be owner/name');
  return { owner, repo };
}
