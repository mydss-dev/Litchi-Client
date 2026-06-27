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
const trackingTimers = new Map<number, ReturnType<typeof setTimeout>>();
const trackingStates = new Map<number, string>();

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
          '请选择打包平台并直接回复:',
          'all',
          'windows',
          'android',
          'macos',
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
    message: { text?: string };
    reply(text: string): Promise<unknown>;
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
    await ctx.reply('平台输入不对，请回复 all / windows / android / macos。');
    return;
  }

  const profile = requireBoundProfile(userId);
  if (profile instanceof Error) {
    await ctx.reply(profile.message);
    return;
  }

  try {
    const version = getCurrentBuildVersion();
    const results: string[] = [];

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

      results.push(`#${id} ${platform} 已进入构建队列`);
      startBuildTracking(bot, {
        buildId: id,
        chatId,
        appId: profile.app_id,
        platform,
        version,
        requestId: dispatched.requestId,
      });
    }

    await ctx.reply(
      [
        `已提交 ${platforms.length} 个打包任务，当前版本 ${version}`,
        ...results,
        '',
        '机器人会自动跟进状态变化，排队中、构建中、成功、失败都会继续通知你。',
      ].join('\n\n'),
    );
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

function startBuildTracking(
  bot: Telegraf,
  input: {
    buildId: number;
    chatId: number;
    appId: string;
    platform: string;
    version: string;
    requestId: string;
  },
): void {
  stopBuildTracking(input.buildId);
  // The submission reply already tells the user this build is queued. Seed
  // the tracker so the first poll does not send the same queued state again.
  trackingStates.set(input.buildId, 'queued');
  scheduleBuildTracking(bot, input, 20000, 0);
}

function scheduleBuildTracking(
  bot: Telegraf,
  input: {
    buildId: number;
    chatId: number;
    appId: string;
    platform: string;
    version: string;
    requestId: string;
  },
  delayMs: number,
  attempt: number,
): void {
  const timer = setTimeout(async () => {
    try {
      const snapshot = await readBuildStatus({
        appId: input.appId,
        platform: input.platform,
        version: input.version,
        requestId: input.requestId,
      });

      if (!snapshot) {
        if (attempt < 60) {
          scheduleBuildTracking(bot, input, 30000, attempt + 1);
        } else {
          stopBuildTracking(input.buildId);
        }
        return;
      }

      updateBuildStatus({
        id: input.buildId,
        status: snapshot.status,
        githubRunUrl: snapshot.githubRunUrl,
        downloadUrl: snapshot.downloadUrl,
      });

      const lastStatus = trackingStates.get(input.buildId);
      if (lastStatus !== snapshot.status) {
        trackingStates.set(input.buildId, snapshot.status);
        await bot.telegram.sendMessage(
          input.chatId,
          formatTrackingMessage(input, snapshot.status, snapshot.downloadUrl),
          {
            link_preview_options: { is_disabled: true },
          },
        );
      }

      if (terminalStatuses.has(snapshot.status)) {
        stopBuildTracking(input.buildId);
        return;
      }

      scheduleBuildTracking(bot, input, 30000, attempt + 1);
    } catch {
      if (attempt < 60) {
        scheduleBuildTracking(bot, input, 30000, attempt + 1);
      } else {
        stopBuildTracking(input.buildId);
      }
    }
  }, delayMs);

  trackingTimers.set(input.buildId, timer);
}

function stopBuildTracking(buildId: number): void {
  const timer = trackingTimers.get(buildId);
  if (timer) clearTimeout(timer);
  trackingTimers.delete(buildId);
  trackingStates.delete(buildId);
}

function formatTrackingMessage(
  input: {
    buildId: number;
    platform: string;
    version: string;
  },
  status: string,
  downloadUrl: string,
): string {
  const statusText = mapStatusText(status);
  const lines = [
    `打包状态更新 #${input.buildId}`,
    `平台: ${input.platform}`,
    `版本: ${input.version}`,
    `状态: ${statusText}`,
  ];
  if (downloadUrl) {
    lines.push(`下载: ${downloadUrl}`);
  }
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
  if (!raw || raw === 'all') return allPlatforms;
  const platform = parseSinglePlatform(raw);
  return platform ? [platform] : [];
}

function parseSinglePlatform(raw?: string): BuildPlatform | undefined {
  if (raw === 'windows' || raw === 'android' || raw === 'macos') return raw;
  return undefined;
}
