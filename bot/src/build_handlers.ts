import type { Telegraf } from 'telegraf';

import { env, isAdmin } from './config.js';
import {
  countRecentBuilds,
  createBuild,
  getAuthorizedUser,
  updateBuildStatus,
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
          `当前版本: ${getCurrentBuildVersion()}`,
          '',
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

  // ── Rate limit ───────────────────────────────────────────────────────────
  if (!isAdmin(userId)) {
    const { maxBuilds, windowHours } = env.buildRateLimit;
    const recent = countRecentBuilds(profile.app_id, windowHours);
    if (recent >= maxBuilds) {
      const resetHint = windowHours >= 24
        ? '明天再试'
        : `${windowHours}小时后再试`;
      await ctx.reply(
        `过去${windowHours}小时内已构建 ${recent} 次（上限 ${maxBuilds} 次），${resetHint}。`,
      );
      return;
    }
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
