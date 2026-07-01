import { Telegraf } from 'telegraf';

import {
  env,
  isAdmin,
  requireAdminConfig,
  requireBotToken,
} from './config.js';
import { getAuthorizedUser } from './db.js';
import {
  resumeBuildTracking,
  wireBuildCommands,
} from './build_handlers.js';
import { buildHelpText, buildStartText, wireCommands } from './handlers.js';
import { wireSignCommands } from './sign_handlers.js';

requireAdminConfig();
const bot = new Telegraf(requireBotToken());
const menuStates = new Map<number, string>();

type MenuCommand = { command: string; description: string };

const baseCommands: MenuCommand[] = [
  { command: 'help', description: '查看当前可用命令' },
  { command: 'myid', description: '查看我的 Telegram ID' },
];
const boundCommands: MenuCommand[] = [
  { command: 'apps', description: '查看当前 APP 绑定' },
  { command: 'config', description: '生成或修改基础配置' },
  { command: 'build', description: '使用已保存配置打包' },
];
const adminCommands: MenuCommand[] = [
  { command: 'authorize', description: '授权用户' },
  { command: 'authorized', description: '查看授权用户' },
  { command: 'revoke', description: '停用用户授权' },
  { command: 'rebindoss', description: '纠正用户 OSS 地址' },
];

async function syncPrivateMenu(input: {
  chatId: number;
  userId: number;
  authorized: boolean;
  bound: boolean;
}): Promise<void> {
  const commands = [...baseCommands];
  if (isAdmin(input.userId)) commands.push(...adminCommands);
  if (input.authorized && !input.bound) {
    commands.push(
      { command: 'bindoss', description: '绑定 OSS 地址' },
      { command: 'config', description: '生成或修改基础配置' },
      { command: 'build', description: '使用已保存配置打包' },
    );
  }
  if (input.bound) commands.push(...boundCommands);

  const state = commands.map((item) => item.command).join(',');
  if (menuStates.get(input.chatId) === state) return;
  await Promise.all([
    bot.telegram.setMyCommands(commands, {
      scope: { type: 'chat', chat_id: input.chatId },
    }),
    bot.telegram.setChatMenuButton({
      chatId: input.chatId,
      menuButton: { type: 'commands' },
    }),
  ]);
  menuStates.set(input.chatId, state);
}

bot.use(async (ctx, next) => {
  const userId = ctx.from?.id;
  const messageText =
    ctx.message && 'text' in ctx.message ? ctx.message.text : undefined;
  const allowPreAuthCommands =
    messageText?.startsWith('/start') ||
    messageText?.startsWith('/help') ||
    messageText?.startsWith('/myid');

  if (!userId) {
    await ctx.reply('无法识别当前用户。');
    return;
  }
  if (ctx.chat && ctx.chat.type !== 'private') {
    await ctx.reply('为保护客户配置和安装包信息，请私聊机器人操作。');
    return;
  }

  const profile = getAuthorizedUser(userId);
  if (ctx.chat?.type === 'private') {
    await syncPrivateMenu({
      chatId: ctx.chat.id,
      userId,
      authorized: Boolean(profile),
      bound: Boolean(
        profile?.app_id && profile.remote_config_url && profile.public_key,
      ),
    }).catch((error) => {
      console.error('Failed to update private command menu', error);
    });
  }

  if (!allowPreAuthCommands && !isAdmin(userId) && !profile) {
    await ctx.reply(
      [
        '未授权，请联系管理员授权。',
        `你的 Telegram ID 是: ${userId}`,
        '你也可以发送 /myid 再查看一次。',
      ].join('\n'),
    );
    return;
  }

  await next();

  // Commands such as /bindoss change the profile during this update. Refresh
  // once more so the Telegram menu immediately reflects the new state.
  if (ctx.chat?.type === 'private') {
    const updated = getAuthorizedUser(userId);
    await syncPrivateMenu({
      chatId: ctx.chat.id,
      userId,
      authorized: Boolean(updated),
      bound: Boolean(
        updated?.app_id && updated.remote_config_url && updated.public_key,
      ),
    }).catch((error) => {
      console.error('Failed to refresh private command menu', error);
    });
  }
});

bot.start((ctx) => ctx.reply(buildStartText(ctx.from?.id)));
bot.help((ctx) => ctx.reply(buildHelpText(ctx.from?.id)));
wireCommands(bot);
wireSignCommands(bot);
wireBuildCommands(bot);

void bot.telegram
  .setMyCommands(baseCommands)
  .catch((error) => {
    console.error('Failed to set bot commands', error);
  });
void bot.telegram
  .setChatMenuButton({ menuButton: { type: 'commands' } })
  .catch((error) => {
    console.error('Failed to set default command menu button', error);
  });

void bot
  .launch(() => {
    console.log('Litchi bot started');
    console.warn(
      `Backup required: keep ${env.dbPath} and KEY_ENCRYPTION_KEY in separate secure backups. Losing either prevents future updates for existing clients.`,
    );
    void resumeBuildTracking(bot).catch((error) => {
      console.error('Failed to resume build tracking', error);
    });
  })
  .catch((error) => {
    console.error('Bot launch failed', error);
    process.exitCode = 1;
  });

process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));
