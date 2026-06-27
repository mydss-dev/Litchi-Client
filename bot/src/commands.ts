import { listAppsForUser } from './db.js';

export function formatApps(userId: number): string {
  const rows = listAppsForUser(userId);
  if (rows.length === 0) return '暂无 App。';
  return rows.map((row) => row.app_id).join('\n');
}
