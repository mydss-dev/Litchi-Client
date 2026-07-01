import type { Telegraf } from 'telegraf';
import { env, isAdmin } from './config.js';
import {
  countRecentBuilds,
  createBuild,
  getAppForUser,
  getAuthorizedUser,
  latestBuild,
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
import {
  matchesPublishedVersion,
  signConfigPayload,
  verifyConfigPayload,
  withReleaseMetadata,
  updateManifestUrl,
} from './signer.js';
import { startConfigFlow } from './sign_handlers.js';

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
  appId: string;
  userId: number;
  chatId: number;
  messageId: number;
  finalConfigSent: boolean;
  builds: Map<
    number,
    {
      platform: string;
      version: string;
      requestId: string;
      status: string;
      downloadUrl: string;
      sha256: string;
    }
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
      await startConfigFlow(ctx);
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
  const app = getAppForUser(profile.app_id, userId);
  if (!app?.signed_config) {
    await ctx.reply('还没有可用于打包的配置，请先发送 /build 并回传模板。');
    return;
  }
  if (!env.downloadBaseUrl) {
    await ctx.reply('缺少 DOWNLOAD_BASE_URL，无法提前生成安装包下载地址。');
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
    const currentConfig = verifyConfigPayload(
      app.signed_config,
      app.public_key,
    );
    if (matchesPublishedVersion(currentConfig, version)) {
      await ctx.reply(
        [
          `提醒：你正在按同版本 ${version} 重新打包。`,
          '这只会更新之后的新下载包。',
          '已安装用户的系统图标和原生软件名称不会变化，必须等下次提高版本并下载安装更新后才会生效。',
        ].join('\n'),
      );
    }
    const groupKey = `${chatId}_${Date.now()}`;
    const group: BuildGroup = {
      appId: profile.app_id,
      userId,
      chatId,
      messageId: 0,
      finalConfigSent: false,
      builds: new Map(),
    };
    groupMessages.set(groupKey, group);

    for (const platform of platforms) {
      const dispatched = await dispatchBuild({
        appId: profile.app_id,
        platform,
        version,
        remoteConfigUrl: profile.remote_config_url,
        verifier: profile.public_key,
        signedConfig: app.signed_config,
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
        downloadUrl: dispatched.downloadUrl,
        sha256: '',
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
        const waitingForPublishedHash =
          build.status === 'success' &&
          build.downloadUrl !== '' &&
          build.sha256 === '';
        if (terminalStatuses.has(build.status) && !waitingForPublishedHash) {
          continue;
        }
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
              sha256: snapshot.sha256,
            });

            if (
              snapshot.status !== build.status ||
              snapshot.downloadUrl !== build.downloadUrl ||
              snapshot.sha256 !== build.sha256
            ) {
              build.status = snapshot.status;
              build.downloadUrl = snapshot.downloadUrl || build.downloadUrl;
              build.sha256 = snapshot.sha256;
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
        await sendFinalConfig(bot, group);
        groupTimers.delete(input.groupKey);
        groupMessages.delete(input.groupKey);
        return;
      }

      if (input.attempt < 60) {
        scheduleGroupPoll(bot, { ...input, delayMs: 30000, attempt: input.attempt + 1 });
      } else {
        await bot.telegram.sendMessage(
          group.chatId,
          '构建状态轮询超时：config.json 不受影响，但 update.json 尚未生成。请检查 GitHub Actions、R2 安装包和 .sha256 文件。',
        );
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
    if (build.sha256) {
      line += `\nSHA-256: ${build.sha256}`;
    }
    lines.push(line);
  }
  lines.push('', '构建成功后会自动生成 update.json，不会要求重新上传 config.json。');
  return lines.join('\n');
}

async function sendFinalConfig(
  bot: Telegraf,
  group: BuildGroup,
): Promise<void> {
  if (group.finalConfigSent) return;

  const successfulBuilds = [...group.builds.values()].filter(
    (build) => build.status === 'success',
  );
  if (successfulBuilds.length === 0) {
    group.finalConfigSent = true;
    await bot.telegram.sendMessage(
      group.chatId,
      '本次构建没有成功的平台，因此没有生成 update.json；原 config.json 不受影响。',
    );
    return;
  }

  const app = getAppForUser(group.appId, group.userId);
  if (!app?.signed_config) {
    throw new Error('找不到基础签名配置，请重新执行 /build。');
  }
  const current = verifyConfigPayload(app.signed_config, app.public_key);
  const version = successfulBuilds[0].version;
  const releases = allPlatforms
    .map((platform) => latestBuild(group.appId, platform))
    .filter(
      (build): build is NonNullable<typeof build> =>
        build != null &&
        build.version === version &&
        build.download_url !== '' &&
        /^[a-f0-9]{64}$/.test(build.sha256),
    )
    .map((build) => ({
      platform: build.platform,
      version: build.version,
      downloadUrl: build.download_url,
      sha256: build.sha256,
    }));
  if (releases.length === 0) {
    group.finalConfigSent = true;
    await bot.telegram.sendMessage(
      group.chatId,
      '构建已成功，但暂时没有读取到安装包 SHA-256，因此没有生成 update.json。请检查 R2 中安装包旁边的 .sha256 文件。',
    );
    return;
  }

  const releasePayload = withReleaseMetadata({}, releases);
  const payload = {
    ...releasePayload,
    update_changelog:
      typeof current.update_changelog === 'string'
        ? current.update_changelog
        : '',
  };
  const signed = signConfigPayload(payload, app.private_key);
  const signedJson = JSON.stringify(signed, null, 2);

  await bot.telegram.sendDocument(
    group.chatId,
    {
      source: Buffer.from(signedJson, 'utf8'),
      filename: 'update.json',
    },
    {
      caption: [
        '更新文件已生成，版本、下载地址和真实 SHA-256 都已自动填好。',
        `请保持文件名 update.json，并上传到：${updateManifestUrl(app.remote_config_url)}`,
        '首次交付没有旧用户需要更新，可以先不上传；以后向已安装旧版本用户推送更新时再上传。',
        '不需要重新上传 config.json；不上传 update.json 就不会发布本次更新。',
      ].join('\n'),
    },
  );

  const packageLines = releases.map(
    (release) => `- ${release.platform}: ${release.downloadUrl}`,
  );
  await bot.telegram.sendMessage(
    group.chatId,
    [
      '构建完成，update.json 已发送。',
      '',
      '安装包下载地址：',
      ...packageLines,
      '',
      `1. 上传 update.json 覆盖到：${updateManifestUrl(app.remote_config_url)}`,
      '2. 浏览器打开该地址，确认不是 404、HTML 或旧内容。',
      '3. 在测试设备安装上面的安装包，检查名称、Logo、登录、节点和连接。',
    ].join('\n'),
    { link_preview_options: { is_disabled: true } },
  );
  group.finalConfigSent = true;
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
