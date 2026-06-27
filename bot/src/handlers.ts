import type { Telegraf } from 'telegraf';

import { isAdmin } from './config.js';
import {
  authorizeUser,
  bindAuthorizedUser,
  getAuthorizedUser,
  listAuthorizedUsers,
} from './db.js';
import {
  clearPendingAction,
  getPendingAction,
  setPendingAction,
} from './flow_state.js';
import { generateKeyPair } from './signer.js';

export function wireCommands(bot: Telegraf): void {
  bot.command('cancel', async (ctx) => {
    const userId = ctx.from?.id;
    if (!userId) {
      await ctx.reply('无法识别当前用户。');
      return;
    }

    clearPendingAction(userId);
    await ctx.reply('已取消当前输入流程。');
  });

  bot.command('authorize', async (ctx) => {
    const adminId = ctx.from?.id;
    if (!isAdmin(adminId) || !adminId) {
      await ctx.reply('只有管理员可以授权用户。');
      return;
    }

    const [targetIdRaw] = splitArgs(ctx.message.text);
    if (!targetIdRaw) {
      setPendingAction(adminId, { type: 'authorize' });
      await ctx.reply(
        ['请发送要授权的 Telegram 数字 ID。', '例如: 6197401242', '退出请输入 /cancel'].join('\n'),
      );
      return;
    }

    await authorizeTarget(ctx, targetIdRaw, adminId);
  });

  bot.command('authorized', async (ctx) => {
    if (!isAdmin(ctx.from?.id)) {
      await ctx.reply('只有管理员可以查看授权列表。');
      return;
    }

    const rows = listAuthorizedUsers();
    if (rows.length === 0) {
      await ctx.reply('当前还没有已授权用户。');
      return;
    }

    const text = rows
      .slice(0, 50)
      .map((row) => {
        const status = row.oss_domain ? '已绑定' : '待绑定';
        const username = row.username ? ` @${row.username}` : '';
        return `${row.tg_user_id}${username} ${status}`;
      })
      .join('\n');

    await ctx.reply(text);
  });

  bot.command('myid', async (ctx) => {
    const userId = ctx.from?.id;
    if (!userId) {
      await ctx.reply('无法识别当前用户。');
      return;
    }

    const username = ctx.from?.username ? `@${ctx.from.username}` : '未设置用户名';
    await ctx.reply(
      [
        '你的 Telegram 信息如下:',
        `ID: ${userId}`,
        `用户名: ${username}`,
        '',
        '把这个 ID 发给管理员授权即可。',
      ].join('\n'),
    );
  });

  bot.command('bindoss', async (ctx) => {
    const userId = ctx.from?.id;
    if (!userId) {
      await ctx.reply('无法识别当前用户。');
      return;
    }

    const profile = getAuthorizedUser(userId);
    if (!profile) {
      await ctx.reply(
        [
          '未授权，请联系管理员授权。',
          `你的 Telegram ID 是: ${userId}`,
          '你也可以发送 /myid 再查看一次。',
        ].join('\n'),
      );
      return;
    }

    if (profile.oss_domain) {
      await ctx.reply(
        [
          'OSS 地址已经绑定，不能修改。',
          `当前 OSS: ${profile.oss_domain}`,
          `APP_ID: ${profile.app_id}`,
        ].join('\n'),
      );
      return;
    }

    const [ossRaw] = splitArgs(ctx.message.text);
    if (!ossRaw) {
      setPendingAction(userId, { type: 'bindoss' });
      await ctx.reply(
        ['请发送你的 OSS 地址。', '例如: https://oss.litchi.cfd', '退出请输入 /cancel'].join('\n'),
      );
      return;
    }

    await bindOssForUser(ctx, ossRaw, userId);
  });

  bot.command('apps', async (ctx) => {
    const userId = ctx.from?.id;
    const profile = userId ? getAuthorizedUser(userId) : undefined;
    if (!profile) {
      await ctx.reply(
        [
          '未授权，请联系管理员授权。',
          `你的 Telegram ID 是: ${userId ?? '未知'}`,
          '发送 /myid 可以再次查看。',
        ].join('\n'),
      );
      return;
    }

    if (!profile.app_id) {
      await ctx.reply('你已获得授权，但还没有绑定 OSS。请先发送 /bindoss');
      return;
    }

    await ctx.reply(formatProfile(profile), {
      link_preview_options: { is_disabled: true },
    });
  });

  bot.on('text', async (ctx, next) => {
    const userId = ctx.from?.id;
    const text = ctx.message.text?.trim() ?? '';
    if (!userId || !text || text.startsWith('/')) {
      await next();
      return;
    }

    const pending = getPendingAction(userId);
    if (!pending || (pending.type !== 'authorize' && pending.type !== 'bindoss')) {
      await next();
      return;
    }

    if (pending.type === 'authorize') {
      clearPendingAction(userId);
      await authorizeTarget(ctx, text, userId);
      return;
    }

    if (pending.type === 'bindoss') {
      clearPendingAction(userId);
      await bindOssForUser(ctx, text, userId);
      return;
    }

    await next();
  });
}

export function buildHelpText(userId?: number): string {
  if (isAdmin(userId)) {
    const lines = [
      '管理员命令:',
      '/authorize',
      '/authorized',
    ];
    const profile = userId ? getAuthorizedUser(userId) : undefined;
    if (profile?.app_id) {
      lines.push(
        '',
        '打包命令:',
        '/apps',
        '/signconfig',
        '/build',
        '/status',
        '/latest',
      );
    }
    return [...lines, '', '输入过程中可随时发送 /cancel。'].join('\n');
  }

  const profile = userId ? getAuthorizedUser(userId) : undefined;
  if (!profile) {
    return ['可用命令:', '/myid', '', '请把 ID 发给管理员授权。'].join('\n');
  }
  if (!profile.app_id) {
    return ['可用命令:', '/myid', '/bindoss'].join('\n');
  }
  return [
    '可用命令:',
    '/apps',
    '/signconfig',
    '/build',
    '/status',
    '/latest',
    '',
    '输入过程中可随时发送 /cancel。',
  ].join('\n');
}

export function buildStartText(userId?: number): string {
  const adminText = isAdmin(userId)
    ? '你是管理员，可以先发送 /authorize，然后按提示输入用户 ID。'
    : [
        `你的 Telegram ID 是: ${userId ?? '未知'}`,
        '如果提示未授权，请把这个 ID 发给管理员。',
        '你也可以随时发送 /myid 再查看一次。',
      ].join('\n');

  return [
    'Litchi 打包机器人已启动。',
    adminText,
    '首次授权后的用户请先发送 /bindoss，然后按提示绑定 OSS。',
    '查看命令帮助请发送 /help',
  ].join('\n');
}

export function buildAppId(userId: number): string {
  return `client_${userId}`;
}

export function normalizeOssDomain(raw: string): string {
  const input = raw.trim();
  const url = new URL(input);
  if (url.protocol !== 'https:' || !url.hostname) {
    throw new Error('OSS 地址必须是 https 域名或 https 路径。');
  }
  if (url.search || url.hash) {
    throw new Error('OSS 地址不能带查询参数或锚点。');
  }

  let path = url.pathname.replace(/\/+$/, '');
  if (path.toLowerCase().endsWith('/config.json')) {
    path = path.slice(0, -'/config.json'.length);
  }

  return `${url.origin}${path}`;
}

function formatProfile(profile: {
  app_id: string;
  oss_domain: string;
  remote_config_url: string;
  public_key: string;
}): string {
  return [
    `APP_ID=${profile.app_id}`,
    `OSS_DOMAIN=${profile.oss_domain || '-'}`,
    `REMOTE_CONFIG_URL=${profile.remote_config_url || '-'}`,
    `REMOTE_CONFIG_PUBLIC_KEY=${profile.public_key || '-'}`,
  ].join('\n');
}

function splitArgs(text = ''): string[] {
  return text.trim().split(/\s+/).slice(1);
}

async function authorizeTarget(
  ctx: {
    reply(text: string): Promise<unknown>;
  },
  targetIdRaw: string,
  adminId: number,
): Promise<void> {
  const targetId = Number.parseInt(targetIdRaw ?? '', 10);
  if (!Number.isFinite(targetId) || targetId <= 0) {
    await ctx.reply('Telegram ID 格式不对，请重新输入纯数字 ID，例如 6197401242。');
    return;
  }

  authorizeUser({
    tgUserId: targetId,
    authorizedBy: adminId,
  });

  await ctx.reply(
    [
      `已授权用户 ${targetId}`,
      '让对方第一次先发送 /myid 确认自己的 ID，',
      '然后再发送 /bindoss 按提示绑定 OSS。',
    ].join('\n'),
  );
}

async function bindOssForUser(
  ctx: {
    from?: { username?: string };
    reply(
      text: string,
      extra?: { link_preview_options: { is_disabled: boolean } },
    ): Promise<unknown>;
  },
  ossRaw: string,
  userId: number,
): Promise<void> {
  try {
    const ossDomain = normalizeOssDomain(ossRaw);
    const appId = buildAppId(userId);
    const remoteConfigUrl = `${ossDomain}/config.json`;
    const keys = generateKeyPair();
    const bound = bindAuthorizedUser({
      tgUserId: userId,
      username: ctx.from?.username,
      ossDomain,
      appId,
      remoteConfigUrl,
      publicKey: keys.publicKey,
      privateKey: keys.privateKey,
    });

    await ctx.reply(
      [
        '绑定成功，以下信息已经固定，请妥善保存。',
        `APP_ID=${bound.app_id}`,
        `OSS_DOMAIN=${bound.oss_domain}`,
        `REMOTE_CONFIG_URL=${bound.remote_config_url}`,
        `REMOTE_CONFIG_PUBLIC_KEY=${bound.public_key}`,
        '',
        '下一步请发送 /signconfig，机器人会继续提示你上传或粘贴配置。',
      ].join('\n'),
      {
        link_preview_options: { is_disabled: true },
      },
    );
  } catch (error) {
    await ctx.reply(error instanceof Error ? error.message : String(error));
  }
}
