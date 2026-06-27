import 'dotenv/config';

export const env = {
  botToken: process.env.BOT_TOKEN ?? '',
  botAdmins: parseAdmins(process.env.BOT_ADMINS ?? ''),
  githubToken: process.env.GITHUB_TOKEN ?? '',
  githubRepo: process.env.GITHUB_REPO ?? 'Kimibit7/Litchi-Client',
  githubRef: process.env.GITHUB_REF ?? 'main',
  githubWorkflowId: process.env.GITHUB_WORKFLOW_ID ?? 'white-label-build.yml',
  buildVersion: process.env.BUILD_VERSION ?? '',
  buildVersionFile: process.env.BUILD_VERSION_FILE ?? '',
  dbPath: process.env.DB_PATH ?? './data/bot.sqlite',
};

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

export function isAdmin(userId?: number): boolean {
  if (!userId) return false;
  if (env.botAdmins.size === 0) return true;
  return env.botAdmins.has(userId);
}

export function isAllowedUser(userId?: number): boolean {
  return isAdmin(userId);
}

export function repoParts(): { owner: string; repo: string } {
  const [owner, repo] = env.githubRepo.split('/');
  if (!owner || !repo) throw new Error('GITHUB_REPO must be owner/name');
  return { owner, repo };
}
