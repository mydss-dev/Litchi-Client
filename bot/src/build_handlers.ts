import type { Telegraf } from 'telegraf';

import {
  createBuild,
  getAuthorizedUser,
  listBuildsForUser,
  setLatestBuild,
  updateBuildStatus,
  type BuildRow,
} from './db.js';
import {
  clearPendingAction,
  getPendingAction,
  setPendingAction,
} from './flow_state.js';
import {
  dispatchBuild,
  getCurrentBuildVersion,
  readBuildStatus,
  type BuildPlatform,
} from './github.js';

const allPlatforms: BuildPlatform[] = ['windows', 'android', 'macos'];
const terminalStatuses = new Set([
  'success',
  'failed',
  'cancelled',
  'timed_out',
  'action_required',
  'skipped',
  'neutral',
]);
/// Each build group (one /build command) gets one entry here.  Status updates
/// edit the same Telegram message instead of sending a new one every time.
type BuildGroup = {
  chatId: number;
  messageId: number;
  builds: Map<
    number,
    { platform: string; version: string; requestId: string; status: string; downloadUrl: string }
  >;
};

const groupMessages = new Map<string, BuildGroup>();
const groupTimers = new Map<string, ReturnType<typeof setTimeout>>();

export function wireBuildCommands(bot: Telegraf): void {
  bot.command('build', async (ctx) => {
    const userId = ctx.from?.id;
    if (!userId) {
      await ctx.reply('无法识别当前会话。');
      return;
    }

    const [platformRaw] = splitArgs(ctx.message.text);
    if (!platformRaw) {
      setPendingAction(userId, { type: 'build' });
      await ctx.reply(
        [
          '请回复数字选择打包平台:',
          '1 — 全部 (Windows + Android + macOS)',
          '2 — Windows',
          '3 — Android',
          '4 — macOS',
          '退出请输入 /cancel',
        ].join('\n'),
      );
      return;
    }

    await startBuildFromInput(bot, ctx, platformRaw);
  });

  bot.command('status', async (ctx) => {
    const userId = ctx.from?.id;
    if (!userId) {
      await ctx.reply('无法识别当前用户。');
      return;
    }

    const profile = requireBoundProfile(userId);
    if (profile instanceof Error) {
      await ctx.reply(profile.message);
      return;
    }

    const rows = listBuildsForUser(profile.app_id, userId);
    if (rows.length === 0) {
      await ctx.reply('还没有打包记录。');
      return;
    }

    const refreshedRows = await refreshBuildRows(rows);
    await ctx.reply(
      refreshedRows
        .map(
          (row) =>
            `#${row.id} ${row.platform} ${row.version} ${row.status}\n${row.download_url || '等待构建完成后生成下载链接'}`,
        )
        .join('\n\n'),
    );
  });

  bot.command('latest', async (ctx) => {
    const userId = ctx.from?.id;
    if (!userId) {
      await ctx.reply('无法识别当前用户。');
      return;
    }

    const profile = requireBoundProfile(userId);
    if (profile instanceof Error) {
      await ctx.reply(profile.message);
      return;
    }

    const rows = listBuildsForUser(profile.app_id, userId).filter(
      (row) => row.status === 'success' && row.download_url,
    );
    if (rows.length === 0) {
      await ctx.reply('还没有可下载的最新包。');
      return;
    }

    await ctx.reply(
      rows
        .map((row) => `${row.platform} ${row.version}\n${row.download_url}`)
        .join('\n\n'),
    );
  });

  bot.command('setlatest', async (ctx) => {
    const userId = ctx.from?.id;
    if (!userId) {
      await ctx.reply('无法识别当前用户。');
      return;
    }

    const [platformRaw, downloadUrl] = splitArgs(ctx.message.text);
    if (!platformRaw) {
      setPendingAction(userId, { type: 'setlatest_platform' });
      await ctx.reply(
        ['请先发送平台名称:', 'windows', 'android', 'macos', '退出请输入 /cancel'].join('\n'),
      );
      return;
    }

    const platform = parseSinglePlatform(platformRaw);
    if (!platform) {
      await ctx.reply('平台只能是 windows / android / macos。');
      return;
    }

    if (!downloadUrl) {
      setPendingAction(userId, { type: 'setlatest_url', platform });
      await ctx.reply(`请发送 ${platform} 的下载链接。`);
      return;
    }

    await saveLatestBuild(ctx, platform, downloadUrl);
  });

  bot.on('text', async (ctx, next) => {
    const userId = ctx.from?.id;
    const text = ctx.message.text?.trim() ?? '';
    if (!userId || !text || text.startsWith('/')) {
      await next();
      return;
    }

    const pending = getPendingAction(userId);
    if (!pending) {
      await next();
      return;
    }

    if (pending.type === 'build') {
      clearPendingAction(userId);
      await startBuildFromInput(bot, ctx, text);
      return;
    }

    if (pending.type === 'setlatest_platform') {
      const platform = parseSinglePlatform(text);
      if (!platform) {
        await ctx.reply('平台只能是 windows / android / macos，请重新输入。');
        return;
      }
      setPendingAction(userId, { type: 'setlatest_url', platform });
      await ctx.reply(`请发送 ${platform} 的下载链接。`);
      return;
    }

    if (pending.type === 'setlatest_url') {
      clearPendingAction(userId);
      await saveLatestBuild(ctx, pending.platform, text);
      return;
    }

    await next();
  });
}

function requireBoundProfile(userId: number) {
  const profile = getAuthorizedUser(userId);
  if (!profile) {
    return new Error('未授权，请联系管理员授权。');
  }
  if (!profile.app_id || !profile.remote_config_url || !profile.public_key) {
    return new Error('你还没有绑定 OSS，请先发送 /bindoss');
  }
  return profile;
}

async function startBuildFromInput(
  bot: Telegraf,
  ctx: {
    from?: { id?: number };
    chat?: { id?: number };
    message: { text?: string; message_id?: number };
    reply(
      text: string,
      extra?: { link_preview_options?: { is_disabled?: boolean } },
    ): Promise<{ message_id: number }>;
  },
  platformRaw: string,
): Promise<void> {
  const userId = ctx.from?.id;
  const chatId = ctx.chat?.id;
  if (!userId || !chatId) {
    await ctx.reply('无法识别当前会话。');
    return;
  }

  const platforms = parsePlatforms(platformRaw);
  if (!platforms.length) {
    setPendingAction(userId, { type: 'build' });
    await ctx.reply('平台输入不对，请回复 1-4 (1=全部, 2=Windows, 3=Android, 4=macOS)。');
    return;
  }

  const profile = requireBoundProfile(userId);
  if (profile instanceof Error) {
    await ctx.reply(profile.message);
    return;
  }

  // Clean up any previous group for this chat.
  for (const [key, group] of groupMessages) {
    if (group.chatId === chatId) {
      const timer = groupTimers.get(key);
      if (timer) clearTimeout(timer);
      groupTimers.delete(key);
      groupMessages.delete(key);
    }
  }

  try {
    const version = getCurrentBuildVersion();
    const groupKey = `${chatId}_${Date.now()}`;
    const group: BuildGroup = { chatId, messageId: 0, builds: new Map() };
    groupMessages.set(groupKey, group);

    for (const platform of platforms) {
      const dispatched = await dispatchBuild({
        appId: profile.app_id,
        platform,
        version,
        remoteConfigUrl: profile.remote_config_url,
        verifier: profile.public_key,
      });
      const id = createBuild({
        appId: profile.app_id,
        tgUserId: userId,
        requestId: dispatched.requestId,
        platform,
        version,
        status: 'queued',
        githubRunUrl: dispatched.workflowUrl,
      });

      group.builds.set(id, {
        platform,
        version,
        requestId: dispatched.requestId,
        status: 'queued',
        downloadUrl: '',
      });
    }

    const sent = await ctx.reply(formatGroupMessage(group), {
      link_preview_options: { is_disabled: true },
    });
    group.messageId = sent.message_id;

    scheduleGroupPoll(bot, {
      groupKey,
      appId: profile.app_id,
      delayMs: 20000,
      attempt: 0,
    });
  } catch (error) {
    await ctx.reply(error instanceof Error ? error.message : String(error));
  }
}

async function saveLatestBuild(
  ctx: {
    from?: { id?: number };
    reply(text: string): Promise<unknown>;
  },
  platform: BuildPlatform,
  downloadUrl: string,
): Promise<void> {
  const userId = ctx.from?.id;
  if (!userId) {
    await ctx.reply('无法识别当前用户。');
    return;
  }

  const profile = requireBoundProfile(userId);
  if (profile instanceof Error) {
    await ctx.reply(profile.message);
    return;
  }

  const version = getCurrentBuildVersion();
  const id = setLatestBuild({
    appId: profile.app_id,
    tgUserId: userId,
    platform,
    version,
    downloadUrl,
  });
  await ctx.reply(`已记录最新安装包 #${id}`);
}

async function refreshBuildRows(rows: BuildRow[]): Promise<BuildRow[]> {
  const nextRows: BuildRow[] = [];

  for (const row of rows) {
    try {
      const snapshot = await readBuildStatus({
        appId: row.app_id,
        platform: row.platform,
        version: row.version,
        requestId: row.request_id,
      });

      if (snapshot) {
        updateBuildStatus({
          id: row.id,
          status: snapshot.status,
          githubRunUrl: snapshot.githubRunUrl,
          downloadUrl: snapshot.downloadUrl,
        });
        nextRows.push({
          ...row,
          status: snapshot.status,
          github_run_url: snapshot.githubRunUrl,
          download_url: snapshot.downloadUrl || row.download_url,
        });
        continue;
      }
    } catch {
      // Keep last known state if GitHub polling fails.
    }

    nextRows.push(row);
  }

  return nextRows;
}

function scheduleGroupPoll(
  bot: Telegraf,
  input: {
    groupKey: string;
    appId: string;
    delayMs: number;
    attempt: number;
  },
): void {
  const timer = setTimeout(async () => {
    try {
      const group = groupMessages.get(input.groupKey);
      if (!group) return;

      let changed = false;
      let allTerminal = true;

      for (const [buildId, build] of group.builds) {
        if (terminalStatuses.has(build.status)) continue;
        allTerminal = false;

        try {
          const snapshot = await readBuildStatus({
            appId: input.appId,
            platform: build.platform,
            version: build.version,
            requestId: build.requestId,
          });

          if (snapshot) {
            updateBuildStatus({
              id: buildId,
              status: snapshot.status,
              githubRunUrl: snapshot.githubRunUrl,
              downloadUrl: snapshot.downloadUrl,
            });

            if (snapshot.status !== build.status) {
              build.status = snapshot.status;
              build.downloadUrl = snapshot.downloadUrl;
              changed = true;
            }
          }
        } catch {
          // Keep last known state for this build.
        }
      }

      if (changed) {
        try {
          await bot.telegram.editMessageText(
            group.chatId,
            group.messageId,
            undefined,
            formatGroupMessage(group),
            { link_preview_options: { is_disabled: true } },
          );
        } catch {
          // Message may have been deleted — stop tracking.
          groupTimers.delete(input.groupKey);
          groupMessages.delete(input.groupKey);
          return;
        }
      }

      if (allTerminal) {
        groupTimers.delete(input.groupKey);
        groupMessages.delete(input.groupKey);
        return;
      }

      if (input.attempt < 60) {
        scheduleGroupPoll(bot, { ...input, delayMs: 30000, attempt: input.attempt + 1 });
      } else {
        groupTimers.delete(input.groupKey);
        groupMessages.delete(input.groupKey);
      }
    } catch {
      if (input.attempt < 60) {
        scheduleGroupPoll(bot, { ...input, delayMs: 30000, attempt: input.attempt + 1 });
      } else {
        groupTimers.delete(input.groupKey);
        groupMessages.delete(input.groupKey);
      }
    }
  }, input.delayMs);

  groupTimers.set(input.groupKey, timer);
}

function formatGroupMessage(group: BuildGroup): string {
  const lines: string[] = [];
  for (const [id, build] of group.builds) {
    const statusText = mapStatusText(build.status);
    let line = `#${id} ${build.platform} ${build.version} ${statusText}`;
    if (build.downloadUrl) {
      line += `\n${build.downloadUrl}`;
    }
    lines.push(line);
  }
  lines.push('', '状态持续更新中，本条消息会自动刷新。');
  return lines.join('\n');
}

function mapStatusText(status: string): string {
  switch (status) {
    case 'queued':
      return '排队中';
    case 'in_progress':
      return '构建中';
    case 'success':
      return '成功';
    case 'failed':
      return '失败';
    case 'cancelled':
      return '已取消';
    case 'timed_out':
      return '超时';
    case 'action_required':
      return '需要人工处理';
    case 'skipped':
      return '已跳过';
    case 'neutral':
      return '已完成';
    default:
      return status;
  }
}

function splitArgs(text = ''): string[] {
  return text.trim().split(/\s+/).slice(1);
}

function parsePlatforms(raw?: string): BuildPlatform[] {
  if (!raw) return [];
  const trimmed = raw.trim();
  // Numeric shortcuts: 1=all, 2=windows, 3=android, 4=macos
  if (trimmed === '1' || trimmed.toLowerCase() === 'all') return allPlatforms;
  const platform = parseSinglePlatform(trimmed);
  return platform ? [platform] : [];
}

function parseSinglePlatform(raw?: string): BuildPlatform | undefined {
  if (!raw) return undefined;
  const trimmed = raw.trim().toLowerCase();
  if (trimmed === '2' || trimmed === 'windows') return 'windows';
  if (trimmed === '3' || trimmed === 'android') return 'android';
  if (trimmed === '4' || trimmed === 'macos') return 'macos';
  return undefined;
}
