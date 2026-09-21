import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../shared/services/url_opener.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_sheet.dart';

/// The bind command is copied, never rendered with the subscription URL.
class V3TelegramPage extends StatefulWidget {
  const V3TelegramPage({super.key});

  static Future<void> show(BuildContext context) => showV3Sheet<void>(
    context,
    title: v3Copy(context, zh: 'Telegram 通知',
      en: 'Telegram notifications', tw: 'Telegram 通知'),
    builder: (_) => const V3TelegramPage(),
  );

  @override
  State<V3TelegramPage> createState() => _V3TelegramPageState();
}

class _V3TelegramPageState extends State<V3TelegramPage> {
  String _botUsername = '';
  String? _error;
  String? _notice;
  bool _loading = true;
  bool _working = false;

  bool get _bound => AppScope.read(context).accountDetails?.telegramId != null;

  @override
  void initState() {
    super.initState();
    _loadBot();
  }

  Future<void> _loadBot() async {
    try {
      final username = await AppScope.read(context).api.getTelegramBotUsername();
      if (!mounted) return;
      setState(() {
        _botUsername = username;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _clean(error);
      });
    }
  }

  Future<void> _copyBindCommand() async {
    if (_working) return;
    final copied = v3Copy(context, zh: '绑定命令已复制，去 Telegram 粘贴发送',
      en: 'Bind command copied. Paste and send it in Telegram.',
      tw: '綁定指令已複製，請到 Telegram 貼上並傳送');
    setState(() { _working = true; _error = null; _notice = null; });
    try {
      final subscribeUrl = await AppScope.read(context).api.getSubscribeUrl();
      await Clipboard.setData(ClipboardData(text: '/bind $subscribeUrl'));
      if (mounted) setState(() => _notice = copied);
    } catch (error) {
      if (mounted) setState(() => _error = _clean(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openTelegram() async {
    if (_botUsername.isEmpty) return;
    final unavailable = v3Copy(context,
      zh: '无法打开 Telegram，请手动搜索 @$_botUsername',
      en: 'Cannot open Telegram. Search for @$_botUsername manually.',
      tw: '無法開啟 Telegram，請手動搜尋 @$_botUsername');
    final opened = await UrlOpener.open('https://t.me/$_botUsername');
    if (!mounted || opened) return;
    setState(() => _error = unavailable);
  }

  Future<void> _refreshStatus() async {
    if (_working) return;
    setState(() { _working = true; _error = null; });
    try {
      await AppScope.read(context).refreshData();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = _clean(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _unbind() async {
    if (_working) return;
    final controller = AppScope.read(context);
    final success = v3Copy(context, zh: 'Telegram 已解绑',
      en: 'Telegram unlinked', tw: 'Telegram 已解除綁定');
    setState(() { _working = true; _error = null; });
    try {
      await controller.api.unbindTelegram();
      await controller.refreshData();
      if (mounted) setState(() => _notice = success);
    } catch (error) {
      if (mounted) setState(() => _error = _clean(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  static String _clean(Object error) => error.toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final bound = _bound;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      V3Panel(
        tone: V3PanelTone.hero,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(color: p.lycheeSoft,
              borderRadius: BorderRadius.circular(V3Radius.field)),
            child: Icon(Icons.send_rounded, size: 20, color: p.lycheeInk)),
          const SizedBox(width: 13),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_loading ? v3Copy(context, zh: '正在读取机器人…',
                    en: 'Loading bot…', tw: '正在讀取機器人…')
                  : _botUsername.isEmpty ? 'Telegram Bot' : '@$_botUsername',
                style: TextStyle(color: p.ink, fontSize: 13,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(bound ? v3Copy(context,
                    zh: '已绑定，可接收账户通知',
                    en: 'Linked. Account alerts are enabled.',
                    tw: '已綁定，可接收帳戶通知')
                  : v3Copy(context, zh: '未绑定，按下方步骤连接',
                    en: 'Not linked. Follow the steps below.',
                    tw: '尚未綁定，請按照以下步驟連結'),
                style: TextStyle(color: bound ? p.successInk : p.inkMuted,
                  fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          )),
        ]),
      ),
      if (_error != null || _notice != null) ...[
        const SizedBox(height: 12),
        Semantics(liveRegion: true,
          child: Text(_error ?? _notice!,
            style: TextStyle(color: _error != null ? p.dangerInk : p.successInk,
              fontSize: 11))),
      ],
      const SizedBox(height: 18),
      if (bound)
        V3ActionButton(label: v3Copy(context, zh: '解除绑定',
          en: 'Unlink Telegram', tw: '解除綁定'),
          icon: Icons.link_off_rounded, secondary: true,
          busy: _working, onPressed: _working ? null : _unbind)
      else ...[
        Text(v3Copy(context,
          zh: '复制绑定命令，打开机器人后粘贴发送。订阅地址不会在这里显示。',
          en: 'Copy the bind command, then paste and send it to the bot. Your subscription URL is not shown here.',
          tw: '複製綁定指令，開啟機器人後貼上並傳送。訂閱網址不會顯示在此處。'),
          style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        V3ActionButton(label: v3Copy(context, zh: '复制绑定命令',
          en: 'Copy bind command', tw: '複製綁定指令'),
          icon: Icons.content_copy_rounded, busy: _working,
          onPressed: _working || _loading ? null : _copyBindCommand),
        const SizedBox(height: 10),
        V3ActionButton(label: v3Copy(context, zh: '打开 Telegram',
          en: 'Open Telegram', tw: '開啟 Telegram'),
          icon: Icons.send_rounded, secondary: true,
          onPressed: _loading || _botUsername.isEmpty ? null : _openTelegram),
        const SizedBox(height: 4),
        TextButton(onPressed: _working ? null : _refreshStatus,
          child: Text(v3Copy(context, zh: '我已完成绑定，刷新状态',
            en: 'I’ve linked it. Refresh status.',
            tw: '我已完成綁定，重新整理狀態'))),
      ],
    ]);
  }
}
