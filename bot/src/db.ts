import fs from 'node:fs';
import path from 'node:path';

import Database from 'better-sqlite3';

import { env } from './config.js';

fs.mkdirSync(path.dirname(env.dbPath), { recursive: true });

export const db = new Database(env.dbPath);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');
if (process.platform !== 'win32') {
  fs.chmodSync(env.dbPath, 0o600);
}

db.exec(`
CREATE TABLE IF NOT EXISTS apps (
  app_id TEXT PRIMARY KEY,
  tg_user_id INTEGER NOT NULL,
  remote_config_url TEXT NOT NULL,
  public_key TEXT NOT NULL,
  private_key TEXT NOT NULL,
  config_version INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS builds (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  app_id TEXT NOT NULL,
  tg_user_id INTEGER NOT NULL,
  request_id TEXT NOT NULL DEFAULT '',
  platform TEXT NOT NULL,
  version TEXT NOT NULL,
  status TEXT NOT NULL,
  download_url TEXT NOT NULL DEFAULT '',
  github_run_url TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY(app_id) REFERENCES apps(app_id)
);

CREATE TABLE IF NOT EXISTS authorized_users (
  tg_user_id INTEGER PRIMARY KEY,
  authorized_by INTEGER NOT NULL,
  username TEXT NOT NULL DEFAULT '',
  oss_domain TEXT NOT NULL DEFAULT '',
  app_id TEXT NOT NULL DEFAULT '',
  remote_config_url TEXT NOT NULL DEFAULT '',
  public_key TEXT NOT NULL DEFAULT '',
  private_key TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
`);

const buildColumns = db.pragma('table_info(builds)') as Array<{ name: string }>;
if (!buildColumns.some((column) => column.name === 'request_id')) {
  db.exec("ALTER TABLE builds ADD COLUMN request_id TEXT NOT NULL DEFAULT ''");
}

export type AppRow = {
  app_id: string;
  tg_user_id: number;
  remote_config_url: string;
  public_key: string;
  private_key: string;
  config_version: number;
  created_at: string;
  updated_at: string;
};

export type BuildRow = {
  id: number;
  app_id: string;
  tg_user_id: number;
  request_id: string;
  platform: string;
  version: string;
  status: string;
  download_url: string;
  github_run_url: string;
  created_at: string;
  updated_at: string;
};

export type AuthorizedUserRow = {
  tg_user_id: number;
  authorized_by: number;
  username: string;
  oss_domain: string;
  app_id: string;
  remote_config_url: string;
  public_key: string;
  private_key: string;
  created_at: string;
  updated_at: string;
};

export function createApp(input: {
  appId: string;
  tgUserId: number;
  remoteConfigUrl: string;
  publicKey: string;
  privateKey: string;
}): void {
  db.prepare(`
    INSERT INTO apps (app_id, tg_user_id, remote_config_url, public_key, private_key)
    VALUES (@appId, @tgUserId, @remoteConfigUrl, @publicKey, @privateKey)
  `).run(input);
}

export function upsertImportedApp(input: {
  appId: string;
  tgUserId: number;
  remoteConfigUrl: string;
  publicKey: string;
  privateKey: string;
}): void {
  db.prepare(`
    INSERT INTO apps (app_id, tg_user_id, remote_config_url, public_key, private_key)
    VALUES (@appId, @tgUserId, @remoteConfigUrl, @publicKey, @privateKey)
    ON CONFLICT(app_id) DO UPDATE SET
      tg_user_id = excluded.tg_user_id,
      remote_config_url = excluded.remote_config_url,
      public_key = excluded.public_key,
      private_key = excluded.private_key,
      updated_at = CURRENT_TIMESTAMP
  `).run(input);
}

export function getAppForUser(appId: string, tgUserId: number): AppRow | undefined {
  return db.prepare(`
    SELECT * FROM apps WHERE app_id = ? AND tg_user_id = ?
  `).get(appId, tgUserId) as AppRow | undefined;
}

export function listAppsForUser(tgUserId: number): AppRow[] {
  return db.prepare(`
    SELECT * FROM apps WHERE tg_user_id = ? ORDER BY created_at DESC
  `).all(tgUserId) as AppRow[];
}

export function bumpConfigVersion(appId: string): number {
  const tx = db.transaction(() => {
    db.prepare(`
      UPDATE apps
      SET config_version = config_version + 1, updated_at = CURRENT_TIMESTAMP
      WHERE app_id = ?
    `).run(appId);

    const row = db.prepare(`
      SELECT config_version FROM apps WHERE app_id = ?
    `).get(appId) as { config_version: number } | undefined;

    if (!row) throw new Error('应用不存在。');
    return row.config_version;
  });
  return tx();
}

export function createBuild(input: {
  appId: string;
  tgUserId: number;
  requestId: string;
  platform: string;
  version: string;
  status: string;
  githubRunUrl?: string;
}): number {
  const result = db.prepare(`
    INSERT INTO builds (
      app_id, tg_user_id, request_id, platform, version, status, github_run_url
    )
    VALUES (
      @appId, @tgUserId, @requestId, @platform, @version, @status, @githubRunUrl
    )
  `).run({ ...input, githubRunUrl: input.githubRunUrl ?? '' });
  return Number(result.lastInsertRowid);
}

export function setLatestBuild(input: {
  appId: string;
  tgUserId: number;
  platform: string;
  version: string;
  downloadUrl: string;
}): number {
  const result = db.prepare(`
    INSERT INTO builds (app_id, tg_user_id, platform, version, status, download_url)
    VALUES (@appId, @tgUserId, @platform, @version, 'success', @downloadUrl)
  `).run(input);
  return Number(result.lastInsertRowid);
}

export function listBuildsForUser(appId: string, tgUserId: number): BuildRow[] {
  return db.prepare(`
    SELECT * FROM builds
    WHERE app_id = ? AND tg_user_id = ?
    ORDER BY created_at DESC
    LIMIT 10
  `).all(appId, tgUserId) as BuildRow[];
}

export function updateBuildStatus(input: {
  id: number;
  status: string;
  githubRunUrl?: string;
  downloadUrl?: string;
}): void {
  db.prepare(`
    UPDATE builds
    SET
      status = @status,
      github_run_url = CASE
        WHEN @githubRunUrl IS NULL OR @githubRunUrl = '' THEN github_run_url
        ELSE @githubRunUrl
      END,
      download_url = CASE
        WHEN @downloadUrl IS NULL OR @downloadUrl = '' THEN download_url
        ELSE @downloadUrl
      END,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = @id
  `).run({
    ...input,
    githubRunUrl: input.githubRunUrl ?? '',
    downloadUrl: input.downloadUrl ?? '',
  });
}

export function latestBuild(appId: string, platform: string): BuildRow | undefined {
  const rows = db.prepare(`
    SELECT * FROM builds
    WHERE app_id = ? AND platform = ? AND status = 'success' AND download_url != ''
  `).all(appId, platform) as BuildRow[];

  return rows.sort((a, b) => {
    const versionDiff = compareVersions(b.version, a.version);
    if (versionDiff !== 0) return versionDiff;
    return String(b.created_at).localeCompare(String(a.created_at));
  })[0];
}

export function authorizeUser(input: {
  tgUserId: number;
  authorizedBy: number;
  username?: string;
}): void {
  db.prepare(`
    INSERT INTO authorized_users (tg_user_id, authorized_by, username)
    VALUES (@tgUserId, @authorizedBy, @username)
    ON CONFLICT(tg_user_id) DO UPDATE SET
      authorized_by = excluded.authorized_by,
      username = CASE
        WHEN excluded.username != '' THEN excluded.username
        ELSE authorized_users.username
      END,
      updated_at = CURRENT_TIMESTAMP
  `).run({
    ...input,
    username: input.username?.trim() ?? '',
  });
}

export function listAuthorizedUsers(): AuthorizedUserRow[] {
  return db.prepare(`
    SELECT * FROM authorized_users
    ORDER BY created_at DESC
  `).all() as AuthorizedUserRow[];
}

export function getAuthorizedUser(tgUserId: number): AuthorizedUserRow | undefined {
  return db.prepare(`
    SELECT * FROM authorized_users WHERE tg_user_id = ?
  `).get(tgUserId) as AuthorizedUserRow | undefined;
}

export function isAuthorizedUser(tgUserId: number): boolean {
  const row = db.prepare(`
    SELECT 1 FROM authorized_users WHERE tg_user_id = ? LIMIT 1
  `).get(tgUserId) as { 1: number } | undefined;
  return Boolean(row);
}

export function bindAuthorizedUser(input: {
  tgUserId: number;
  username?: string;
  ossDomain: string;
  appId: string;
  remoteConfigUrl: string;
  publicKey: string;
  privateKey: string;
}): AuthorizedUserRow {
  const tx = db.transaction(() => {
    const current = getAuthorizedUser(input.tgUserId);
    if (!current) throw new Error('未授权，请联系管理员授权。');
    if (current.oss_domain) {
      throw new Error('OSS 地址已经绑定，不能修改。');
    }

    db.prepare(`
      UPDATE authorized_users
      SET
        username = @username,
        oss_domain = @ossDomain,
        app_id = @appId,
        remote_config_url = @remoteConfigUrl,
        public_key = @publicKey,
        private_key = @privateKey,
        updated_at = CURRENT_TIMESTAMP
      WHERE tg_user_id = @tgUserId
    `).run({
      ...input,
      username: input.username?.trim() ?? current.username,
    });

    upsertImportedApp({
      appId: input.appId,
      tgUserId: input.tgUserId,
      remoteConfigUrl: input.remoteConfigUrl,
      publicKey: input.publicKey,
      privateKey: input.privateKey,
    });

    const updated = getAuthorizedUser(input.tgUserId);
    if (!updated) throw new Error('绑定失败，请稍后重试。');
    return updated;
  });

  return tx();
}

function compareVersions(left: string, right: string): number {
  const leftParts = normalizeVersion(left);
  const rightParts = normalizeVersion(right);
  const maxLen = Math.max(leftParts.length, rightParts.length);
  for (let i = 0; i < maxLen; i += 1) {
    const a = leftParts[i] ?? 0;
    const b = rightParts[i] ?? 0;
    if (a !== b) return a - b;
  }
  return 0;
}

function normalizeVersion(version: string): number[] {
  return version
    .split('.')
    .map((part) => Number.parseInt(part, 10))
    .map((part) => (Number.isFinite(part) && part >= 0 ? part : 0));
}
