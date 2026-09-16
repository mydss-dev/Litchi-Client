import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_controller.dart';
import '../../shared/services/url_opener.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_sheet.dart';

/// Bind the account to a Telegram bot so expiry and traffic notices reach the
/// user out of the app.
///
/// The bind happens outside the app: Litchi copies a `/bind <subscribe-url>`
/// command, the user sends it to the panel's bot, and the result shows up in
/// the account's `telegram_id`. Only Xiao-V2Board exposes the endpoints, so the
/// row that opens this is gated behind [PanelFeatures.telegram].
class V3TelegramPage extends StatefulWidget {
  const V3TelegramPage({super.key});

  /// Opens the Telegram binding flow as a sheet.
  static Future<void> show(BuildContext context) => showV3Sheet<void>(
    context,
    title: 'Telegram 通知',
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
      final username = await AppScope.read(
        context,
      ).api.getTelegramBotUsername();
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
    setState(() {
      _working = true;
      _error = null;
      _notice = null;
    });
    try {
      final subscribeUrl = await AppScope.read(context).api.getSubscribeUrl();
      await Clipboard.setData(ClipboardData(text: '/bind $subscribeUrl'));
      if (mounted) setState(() => _notice = '绑定命令已复制，去 Telegram 粘贴发送');
    } catch (error) {
      if (mounted) setState(() => _error = _clean(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openTelegram() async {
    if (_botUsername.isEmpty) return;
    final opened = await UrlOpener.open('https://t.me/$_botUsername');
    if (!mounted || opened) return;
    setState(() => _error = '无法打开 Telegram，请手动搜索 @$_botUsername');
  }

  Future<void> _refreshStatus() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
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
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await controller.api.unbindTelegram();
      await controller.refreshData();
      if (mounted) setState(() => _notice = 'Telegram 已解绑');
    } catch (error) {
      if (mounted) setState(() => _error = _clean(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  static String _clean(Object error) => error
      .toString()
      .replaceFirst('ApiException: ', '')
      .replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final bound = _bound;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        V3Panel(
          tone: V3PanelTone.hero,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: p.lycheeSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.send_rounded, size: 20, color: p.lycheeInk),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loading
                          ? '正在读取机器人…'
                          : _botUsername.isEmpty
                          ? 'Telegram Bot'
                          : '@$_botUsername',
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bound ? '已绑定，可接收账户通知' : '未绑定，按下方步骤连接',
                      style: TextStyle(
                        color: bound ? p.successInk : p.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_error != null || _notice != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _error ?? _notice!,
              style: TextStyle(
                color: _error != null ? p.dangerInk : p.successInk,
                fontSize: 11,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (bound)
          V3ActionButton(
            label: '解除绑定',
            icon: Icons.link_off_rounded,
            secondary: true,
            busy: _working,
            onPressed: _working ? null : _unbind,
          )
        else ...[
          Text(
            '复制绑定命令，打开机器人后粘贴发送。订阅地址不会在这里显示。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          V3ActionButton(
            label: '复制绑定命令',
            icon: Icons.content_copy_rounded,
            busy: _working,
            onPressed: _working || _loading ? null : _copyBindCommand,
          ),
          const SizedBox(height: 10),
          V3ActionButton(
            label: '打开 Telegram',
            icon: Icons.send_rounded,
            secondary: true,
            onPressed: _loading || _botUsername.isEmpty ? null : _openTelegram,
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _working ? null : _refreshStatus,
            child: const Text('我已完成绑定，刷新状态'),
          ),
        ],
      ],
    );
  }
}
