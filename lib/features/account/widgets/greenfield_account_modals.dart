import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/services/url_opener.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';

Future<void> showGreenfieldGiftCardModal(BuildContext context) {
  final controller = AppScope.of(context);
  return showAppAdaptiveModal<void>(
    context: context,
    builder: (_) => _GiftCardModal(controller: controller),
  );
}

Future<void> showGreenfieldTelegramModal(BuildContext context) {
  final controller = AppScope.of(context);
  return showAppAdaptiveModal<void>(
    context: context,
    builder: (_) => _TelegramModal(controller: controller),
  );
}

class _GiftCardModal extends StatefulWidget {
  const _GiftCardModal({required this.controller});

  final AppController controller;

  @override
  State<_GiftCardModal> createState() => _GiftCardModalState();
}

class _GiftCardModalState extends State<_GiftCardModal> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _submitting) {
      if (code.isEmpty) setState(() => _error = context.l10n.giftCardEnterRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.controller.api.redeemGiftCard(code);
      await widget.controller.refreshData();
      if (!mounted) return;
      AppToast.show(
        context,
        context.l10n.giftCardRedeemed,
        type: AppToastType.success,
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppAdaptiveModal(
      title: context.l10n.giftCardTitle,
      subtitle: context.l10n.giftCardModalSubtitle,
      maxWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            color: c.primarySoft.withValues(alpha: 0.42),
            borderColor: c.primary.withValues(alpha: 0.14),
            shadow: AppCardShadow.none,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(LucideIcons.ticketCheck, size: 20, color: c.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    context.l10n.giftCardServiceSubtitle,
                    style: AppTextStyles.body.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _codeController,
            label: context.l10n.giftCardCode,
            hint: context.l10n.giftCardEnterHint,
            errorText: _error,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: context.l10n.giftCardRedeemNow,
            leadingIcon: LucideIcons.ticketCheck,
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
            expand: true,
          ),
        ],
      ),
    );
  }
}

class _TelegramModal extends StatefulWidget {
  const _TelegramModal({required this.controller});

  final AppController controller;

  @override
  State<_TelegramModal> createState() => _TelegramModalState();
}

class _TelegramModalState extends State<_TelegramModal> {
  String _botUsername = '';
  String? _error;
  bool _loading = true;
  bool _working = false;

  bool get _bound => widget.controller.accountDetails?.telegramId != null;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBot());
  }

  Future<void> _loadBot() async {
    try {
      final username = await widget.controller.api.getTelegramBotUsername();
      if (!mounted) return;
      setState(() {
        _botUsername = username;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  Future<void> _copyBindCommand() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final subscribeUrl = await widget.controller.api.getSubscribeUrl();
      await Clipboard.setData(ClipboardData(text: '/bind $subscribeUrl'));
      if (!mounted) return;
      AppToast.show(
        context,
        context.l10n.telegramBindingCommandCopied,
        type: AppToastType.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openTelegram() async {
    if (_botUsername.isEmpty) return;
    final opened = await UrlOpener.open('https://t.me/$_botUsername');
    if (!mounted || opened) return;
    setState(() => _error = context.l10n.telegramOpenFailed(_botUsername));
  }

  Future<void> _refreshStatus() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.controller.refreshData();
      if (mounted) setState(() {});
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _unbind() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.controller.api.unbindTelegram();
      await widget.controller.refreshData();
      if (!mounted) return;
      setState(() {});
      AppToast.show(
        context,
        context.l10n.telegramUnbound,
        type: AppToastType.success,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final status = _bound
        ? context.l10n.telegramConnected
        : context.l10n.telegramNotConnected;

    return AppAdaptiveModal(
      title: 'Telegram',
      subtitle: context.l10n.telegramNotificationsSubtitle,
      maxWidth: 540,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            color: c.surfaceMuted,
            shadow: AppCardShadow.none,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(LucideIcons.send, size: 19, color: c.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loading
                            ? context.l10n.telegramLoadingBot
                            : _botUsername.isEmpty
                                ? 'Telegram Bot'
                                : '@$_botUsername',
                        style: AppTextStyles.bodyStrong,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        status,
                        style: AppTextStyles.caption.copyWith(
                          color: _bound ? c.success : c.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: AppTextStyles.caption.copyWith(color: c.danger)),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_bound)
            AppButton(
              label: context.l10n.telegramUnbind,
              variant: AppButtonVariant.outline,
              loading: _working,
              onPressed: _working ? null : _unbind,
              expand: true,
            )
          else ...[
            Text(
              context.l10n.telegramBindingInstructions,
              style: AppTextStyles.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: context.l10n.telegramCopyCommand,
              leadingIcon: LucideIcons.clipboardList,
              variant: AppButtonVariant.secondary,
              loading: _working,
              onPressed: _working || _loading ? null : _copyBindCommand,
              expand: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: context.l10n.telegramOpen,
              leadingIcon: LucideIcons.send,
              onPressed: _loading || _botUsername.isEmpty ? null : _openTelegram,
              expand: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _working ? null : _refreshStatus,
              child: Text(context.l10n.telegramRefreshBindingStatus),
            ),
          ],
        ],
      ),
    );
  }
}
