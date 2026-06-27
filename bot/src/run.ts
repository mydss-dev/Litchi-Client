import { Telegraf } from 'telegraf';

import { isAdmin, requireBotToken } from './config.js';
import { getAuthorizedUser } from './db.js';
import { wireBuildCommands } from './build_handlers.js';
import { buildHelpText, buildStartText, wireCommands } from './handlers.js';
import { wireSignCommands } from './sign_handlers.js';

const bot = new Telegraf(requireBotToken());

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

  if (!allowPreAuthCommands && !isAdmin(userId) && !getAuthorizedUser(userId)) {
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
});

bot.start((ctx) => ctx.reply(buildStartText(ctx.from?.id)));
bot.help((ctx) => ctx.reply(buildHelpText(ctx.from?.id)));
wireCommands(bot);
wireSignCommands(bot);
wireBuildCommands(bot);

void bot.telegram
  .setMyCommands([
    { command: 'help', description: '获取帮助菜单' },
    { command: 'myid', description: '查看我的 Telegram ID' },
    { command: 'authorize', description: '管理员授权用户' },
    { command: 'authorized', description: '查看授权用户列表' },
    { command: 'bindoss', description: '绑定 OSS 地址' },
    { command: 'apps', description: '查看当前绑定信息' },
    { command: 'signconfig', description: '生成签名 config.json' },
    { command: 'build', description: '触发打包' },
    { command: 'status', description: '查看打包进度' },
    { command: 'latest', description: '查看最新可下载包' },
    { command: 'setlatest', description: '手动记录下载链接' },
    { command: 'cancel', description: '取消当前输入流程' },
  ])
  .catch((error) => {
    console.error('Failed to set bot commands', error);
  });

bot.launch();
console.log('Litchi bot started');

process.once('SIGINT', () => bot.stop('SIGINT'));
process.once('SIGTERM', () => bot.stop('SIGTERM'));
