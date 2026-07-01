import type { Context, Telegraf } from 'telegraf';
import fs from 'node:fs';

import {
  bumpConfigVersion,
  getAppForUser,
  getAuthorizedUser,
  latestSuccessfulVersion,
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
  withUpdateManifestUrl,
} from './signer.js';
import { parseAndValidateConfig } from './validate.js';

const configTemplate = fs.readFileSync(
  new URL('../config.template.json', import.meta.url),
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
    const app = getAppForUser(profile.app_id, userId);
    const previous = app?.signed_config
      ? verifyConfigPayload(app.signed_config, profile.public_key)
      : undefined;
    const payload = withUpdateManifestUrl(
      parseAndValidateConfig(
        JSON.stringify(withPreservedUpdateMetadata(input, previous)),
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

    const targetVersion = getCurrentBuildVersion();
    const publishedVersion =
      latestSuccessfulVersion(profile.app_id) ||
      (typeof previous?.update_version === 'string'
        ? previous.update_version.trim()
        : '');
    const versionMatches =
      publishedVersion !== '' &&
      (publishedVersion === targetVersion ||
        matchesPublishedVersion(previous ?? {}, targetVersion));

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
        ].join('\n'),
      },
    );

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
    await ctx.reply(
      [
        '已选择只发布热配置，不重新打包。',
        `请上传刚才收到的 config.json 覆盖到：${pending.remoteConfigUrl}`,
        '上传后重启客户端检查 API、头像、邀请地址或文案是否生效。',
      ].join('\n'),
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
