import type { Context, Telegraf } from 'telegraf';
import fs from 'node:fs';

import {
  bumpConfigVersion,
  getAppForUser,
  getAuthorizedUser,
  saveSignedConfig,
} from './db.js';
import {
  clearPendingAction,
  getPendingAction,
  setPendingAction,
} from './flow_state.js';
import { getCurrentBuildVersion } from './github.js';
import {
  signConfigPayload,
  matchesPublishedVersion,
  verifyConfigPayload,
  withConfigVersion,
  withPreservedUpdateMetadata,
} from './signer.js';
import { parseAndValidateConfig } from './validate.js';

const configTemplate = fs.readFileSync(
  new URL('../config.template.js', import.meta.url),
);

export function wireSignCommands(bot: Telegraf): void {
  bot.command('signconfig', async (ctx) => {
    const text = ctx.message.text ?? '';
    const rawConfig = extractConfigFromCommandText(text);
    if (!rawConfig) {
      await startConfigFlow(ctx);
      return;
    }

    await signAndReply(ctx, rawConfig);
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

    if (pending.type === 'signconfig') {
      clearPendingAction(userId);
      await signAndReply(ctx, text);
      return;
    }

    if (pending.type === 'same_version_choice') {
      await handleSameVersionChoice(ctx, userId, text, pending);
      return;
    }

    await next();
  });

  bot.on('document', async (ctx, next) => {
    const userId = ctx.from?.id;
    const caption = ctx.message.caption ?? '';
    const fileName = (ctx.message.document.file_name ?? '').toLowerCase();
    const pending = userId ? getPendingAction(userId) : undefined;
    const shouldHandle =
      pending?.type === 'signconfig' ||
      caption.includes('/signconfig') ||
      fileName === 'config.js' ||
      fileName === 'config.json' ||
      fileName === 'config.template.js' ||
      fileName.endsWith('.config.js') ||
      fileName.endsWith('.config.json');

    if (!shouldHandle) {
      await next();
      return;
    }

    if (userId && pending?.type === 'signconfig') {
      clearPendingAction(userId);
    }

    try {
      const link = await ctx.telegram.getFileLink(ctx.message.document.file_id);
      const response = await fetch(link.toString());
      if (!response.ok) {
        throw new Error(`下载配置文件失败: HTTP ${response.status}`);
      }

      const rawConfig = await response.text();
      if (!rawConfig.trim()) {
        throw new Error('上传的配置文件是空的。');
      }

      await signAndReply(ctx, rawConfig);
    } catch (error) {
      if (userId) setPendingAction(userId, { type: 'signconfig' });
      await ctx.reply(error instanceof Error ? error.message : String(error));
    }
  });
}

export async function startConfigFlow(ctx: Context): Promise<void> {
  const userId = ctx.from?.id;
  const profile = userId ? getAuthorizedUser(userId) : undefined;
  if (!userId || !profile?.app_id) {
    await ctx.reply('你还没有绑定 OSS，请先发送 /bindoss');
    return;
  }

  setPendingAction(userId, { type: 'signconfig' });
  await ctx.replyWithDocument(
    {
      source: configTemplate,
      filename: 'config.template.js',
    },
    {
      caption: [
        '请下载模板，按注释填写后把 JS 文件直接发回来。',
        '机器人会先校验配置，再根据历史版本自动进入配置发布或打包流程。',
        '版本、下载地址和 SHA-256 不用填写；退出请输入 /cancel。',
      ].join('\n'),
    },
  );
}

async function signAndReply(ctx: Context, rawConfig: string): Promise<void> {
  const userId = ctx.from?.id;
  if (!userId) {
    await ctx.reply('无法识别当前用户。');
    return;
  }

  const profile = getAuthorizedUser(userId);
  if (!profile) {
    await ctx.reply(`未授权，请联系管理员授权。\n你的 Telegram ID: ${userId}`);
    return;
  }
  if (!profile.private_key || !profile.public_key || !profile.app_id) {
    await ctx.reply('你还没有绑定 OSS，请先发送 /bindoss');
    return;
  }

  try {
    const input = parseAndValidateConfig(rawConfig);
    const app = getAppForUser(profile.app_id, userId);
    const previous = app?.signed_config
      ? verifyConfigPayload(app.signed_config, profile.public_key)
      : undefined;
    const payload = parseAndValidateConfig(
      JSON.stringify(withPreservedUpdateMetadata(input, previous)),
    );

    const configVersion = bumpConfigVersion(profile.app_id);
    const signed = signConfigPayload(
      withConfigVersion(payload, configVersion),
      profile.private_key,
    );
    const signedJson = JSON.stringify(signed, null, 2);
    saveSignedConfig(profile.app_id, JSON.stringify(signed));

    const targetVersion = getCurrentBuildVersion();
    const publishedVersion =
      typeof payload.update_version === 'string'
        ? payload.update_version.trim()
        : '';
    const versionMatches = matchesPublishedVersion(payload, targetVersion);
    if (!versionMatches) {
      setPendingAction(userId, { type: 'build' });
      await ctx.reply(
        [
          '配置校验完成，已签名并保存。',
          publishedVersion
            ? `构建版本不一致：上次 ${publishedVersion}，后台目标 ${targetVersion}。`
            : '首次配置还没有已构建版本。',
          '需要生成安装包，请回复数字选择平台：',
          '1 — 全部 (Windows + Android + macOS)',
          '2 — Windows',
          '3 — Android',
          '4 — macOS',
          '退出请输入 /cancel',
        ].join('\n'),
      );
      return;
    }
    setPendingAction(userId, {
      type: 'same_version_choice',
      signedConfig: signedJson,
      remoteConfigUrl: profile.remote_config_url,
      targetVersion,
    });
    await ctx.reply(
      [
        '配置校验完成，已签名并保存。',
        `当前后台版本与上次构建版本相同（${targetVersion}）。`,
        'API、头像、邀请地址和文案等热配置可以直接发布，无需重新打包。',
        'Logo、系统图标和原生应用名称等安装包素材发生变化时才需要重新打包。',
        '请回复数字选择：',
        '1 — 直接发布配置，不打包',
        `2 — 同版本 ${targetVersion} 重新打包（只更新之后的新下载包；已安装用户的系统图标和原生软件名称不会变化，必须等下次提高版本并下载安装更新后才会生效）`,
        '退出请输入 /cancel',
      ].join('\n'),
    );
  } catch (error) {
    setPendingAction(userId, { type: 'signconfig' });
    await ctx.reply(error instanceof Error ? error.message : String(error));
  }
}

async function handleSameVersionChoice(
  ctx: Context,
  userId: number,
  choice: string,
  pending: {
    signedConfig: string;
    remoteConfigUrl: string;
    targetVersion: string;
  },
): Promise<void> {
  if (choice === '1') {
    clearPendingAction(userId);
    await ctx.replyWithDocument(
      {
        source: Buffer.from(pending.signedConfig, 'utf8'),
        filename: 'config.json',
      },
      {
        caption: [
          '已选择只发布热配置，不重新打包。',
          `请保持文件名为 config.json，并上传覆盖到：${pending.remoteConfigUrl}`,
          '上传后用浏览器打开该地址，应看到包含 payload_b64 和 signature 的 JSON；然后重启客户端检查 API、头像、邀请地址或文案是否生效。',
        ].join('\n'),
      },
    );
    return;
  }

  if (choice === '2') {
    setPendingAction(userId, { type: 'build' });
    await ctx.reply(
      [
        `将按同版本 ${pending.targetVersion} 重新打包。`,
        '这只会更新之后的新下载包。',
        '已安装用户的系统图标和原生软件名称不会变化，必须等下次提高版本并下载安装更新后才会生效。',
        '',
        '请回复数字选择打包平台：',
        '1 — 全部 (Windows + Android + macOS)',
        '2 — Windows',
        '3 — Android',
        '4 — macOS',
        '退出请输入 /cancel',
      ].join('\n'),
    );
    return;
  }

  setPendingAction(userId, { type: 'same_version_choice', ...pending });
  await ctx.reply('请输入 1 或 2；退出请输入 /cancel。');
}

function extractConfigFromCommandText(text: string): string {
  const trimmed = text.trim();
  if (!trimmed.startsWith('/signconfig')) {
    return '';
  }

  const sameLine = trimmed.replace(/^\/signconfig(?:@\S+)?\s*/, '');
  if (sameLine && sameLine !== trimmed) {
    return sameLine.trim();
  }

  const lines = text.split('\n');
  return lines.slice(1).join('\n').trim();
}
