import type { Context, Telegraf } from 'telegraf';
import fs from 'node:fs';

import {
  bumpConfigVersion,
  getAuthorizedUser,
  saveSignedConfig,
} from './db.js';
import {
  clearPendingAction,
  getPendingAction,
  setPendingAction,
} from './flow_state.js';
import {
  signConfigPayload,
  withConfigVersion,
  withPreservedUpdateMetadata,
  withUpdateManifestUrl,
} from './signer.js';
import { parseAndValidateConfig } from './validate.js';

const configTemplate = fs.readFileSync(
  new URL('../config.template.json', import.meta.url),
);

export function wireSignCommands(bot: Telegraf): void {
  bot.command('config', startConfigFlow);

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
      fileName === 'config.template.json' ||
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
      filename: 'config.template.json',
    },
    {
      caption: [
        '请下载并填写 JSON 模板，然后把文件直接发回机器人。',
        '不要添加注释，也不要填写版本、下载地址或 SHA-256。',
      ].join('\n'),
    },
  );
  await ctx.reply(
    [
      '字段说明：',
      'app_name：软件名称。',
      'api_base_list：面板 HTTPS API，可按优先级填写多个。',
      'api_prefix：API 路径前缀；没有就填空字符串。',
      'panel_type：v2board、xiao_v2board 或 xboard。',
      'logo_url：公开 HTTPS Logo，推荐 1024×1024 PNG。',
      'avatar_url：可选，账户页品牌图片；不用可删除该行。',
      'invite_url_base：可选，官网或邀请注册地址。',
      'update_enabled：是否读取独立 update.json 并提示更新。',
      'update_changelog：更新说明，最多 200 字。',
      '',
      '机器人校验后立即生成 config.json；打包成功后另行生成已签名的 update.json。',
      '退出请输入 /cancel。',
    ].join('\n'),
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
    const payload = withUpdateManifestUrl(
      parseAndValidateConfig(
        JSON.stringify(withPreservedUpdateMetadata(input)),
      ),
      profile.remote_config_url,
    );

    const configVersion = bumpConfigVersion(profile.app_id);
    const signed = signConfigPayload(
      withConfigVersion(payload, configVersion),
      profile.private_key,
    );
    const signedJson = JSON.stringify(signed, null, 2);
    saveSignedConfig(profile.app_id, JSON.stringify(signed));

    await ctx.replyWithDocument(
      {
        source: Buffer.from(signedJson, 'utf8'),
        filename: 'config.json',
      },
      {
        caption: [
          '基础配置校验完成并已签名。',
          `请保持文件名为 config.json，并上传到：${profile.remote_config_url}`,
          '这个文件以后修改 API、Logo 或文案时才需要重新上传；安装包更新信息会单独生成 update.json。',
          '需要生成安装包时，请发送 /build。',
        ].join('\n'),
      },
    );
    clearPendingAction(userId);
  } catch (error) {
    setPendingAction(userId, { type: 'signconfig' });
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
