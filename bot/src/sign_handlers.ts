import type { Context, Telegraf } from 'telegraf';

import { bumpConfigVersion, getAuthorizedUser } from './db.js';
import {
  clearPendingAction,
  getPendingAction,
  setPendingAction,
} from './flow_state.js';
import { signConfigPayload, withConfigVersion } from './signer.js';
import { parseAndValidateConfig } from './validate.js';

export function wireSignCommands(bot: Telegraf): void {
  bot.command('signconfig', async (ctx) => {
    const text = ctx.message.text ?? '';
    const rawConfig = extractConfigFromCommandText(text);
    if (!rawConfig) {
      const userId = ctx.from?.id;
      if (userId) {
        setPendingAction(userId, { type: 'signconfig' });
      }

      await ctx.reply(
        [
          '请发送你的配置内容。',
          '支持两种方式:',
          '1. 直接粘贴 JSON 或 config.js 内容',
          '2. 直接上传 config.js / config.json 文件',
          'logo_url 请使用 1024×1024 的 HTTPS PNG 图片。',
          '退出请输入 /cancel',
        ].join('\n'),
      );
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
    if (!pending || pending.type !== 'signconfig') {
      await next();
      return;
    }

    clearPendingAction(userId);
    await signAndReply(ctx, text);
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
      await ctx.reply(error instanceof Error ? error.message : String(error));
    }
  });
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
    const payload = parseAndValidateConfig(rawConfig);

    const configVersion = bumpConfigVersion(profile.app_id);
    const signed = signConfigPayload(
      withConfigVersion(payload, configVersion),
      profile.private_key,
    );
    const fileBuffer = Buffer.from(JSON.stringify(signed, null, 2), 'utf8');

    await ctx.reply('配置已签名');
    await ctx.replyWithDocument(
      {
        source: fileBuffer,
        filename: 'config.json',
      },
      {
        caption: [
          'config.json 已生成。',
          `请上传到: ${profile.remote_config_url}`,
          '上传完成后，直接发送 /build，机器人会继续问你打包平台。',
        ].join('\n'),
      },
    );
  } catch (error) {
    await ctx.reply(error instanceof Error ? error.message : String(error));
  }
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
