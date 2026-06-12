import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/config/app_config.dart';
import '../../shared/models/api_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_toast.dart';
import 'widgets/auth_form_parts.dart';
import 'widgets/auth_input.dart';
import 'widgets/auth_primary_button.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  RegisterConfig _config = const RegisterConfig();
  bool _agree = false;
  bool _loading = false;
  bool _sendingCode = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await AppScope.of(context).api.getRegisterConfig();
    if (mounted) {
      setState(() {
        _config = config;
        if (config.emailSuffixes.isNotEmpty) {
          // selectedSuffix is tracked via _EmailSuffixInput's callback
        }
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _prefixCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _inviteCtrl.dispose();
    _codeCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // Selected suffix is tracked separately when suffix list is active.
  String _selectedSuffix = '';

  String get _email => _config.emailSuffixes.isNotEmpty
      ? '${_prefixCtrl.text.trim()}@$_selectedSuffix'
      : _emailCtrl.text.trim();

  Future<void> _sendCode() async {
    final email = _email;
    if (_config.emailSuffixes.isNotEmpty && _prefixCtrl.text.trim().isEmpty) {
      AppToast.show(context, '请先填写邮箱前缀', type: AppToastType.warning);
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      AppToast.show(context, '请先填写正确的邮箱地址', type: AppToastType.warning);
      return;
    }
    if (_sendingCode || _countdown > 0) return;

    setState(() => _sendingCode = true);
    try {
      await AppScope.of(context).api.sendEmailVerify(email);
      if (mounted) {
        AppToast.show(context, '验证码已发送，请查收邮件', type: AppToastType.success);
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          e.toString().replaceFirst('ApiException: ', ''),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) t.cancel();
      });
    });
  }

  Future<void> _submit() async {
    final controller = AppScope.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);
    final email = _email;
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    final invite = _inviteCtrl.text.trim();
    final code = _codeCtrl.text.trim();

    if (_config.emailSuffixes.isNotEmpty && _prefixCtrl.text.trim().isEmpty) {
      AppToast.show(context, '请填写邮箱前缀', type: AppToastType.warning);
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      AppToast.show(context, '请填写邮箱和密码', type: AppToastType.warning);
      return;
    }
    if (password != confirm) {
      AppToast.show(context, '两次密码不一致', type: AppToastType.error);
      return;
    }
    if (_config.emailVerifyRequired && code.isEmpty) {
      AppToast.show(context, '请填写邮件验证码', type: AppToastType.warning);
      return;
    }
    if (!_agree) {
      AppToast.show(context, '请先同意服务条款', type: AppToastType.warning);
      return;
    }

    setState(() => _loading = true);
    try {
      await controller.registerWithCredentials(
        email: email,
        password: password,
        passwordConfirmation: confirm,
        inviteCode: invite.isNotEmpty ? invite : null,
        emailCode: code.isNotEmpty ? code : null,
      );
      AppToast.showInOverlay(
        overlay,
        '注册成功，欢迎加入 ${AppConfig.appName}！',
        type: AppToastType.success,
      );
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          e.toString().replaceFirst('ApiException: ', ''),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = AppScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '注册',
            style: AppTextStyles.authTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '创建你的 ${AppConfig.appName} 账户',
            style: AppTextStyles.authSubtitle.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 20),
          // Email field
          if (_config.emailSuffixes.isNotEmpty)
            _EmailSuffixInput(
              prefixCtrl: _prefixCtrl,
              suffixes: _config.emailSuffixes,
              selected: _selectedSuffix.isEmpty
                  ? _config.emailSuffixes.first
                  : _selectedSuffix,
              onSuffixChanged: (s) => setState(() => _selectedSuffix = s),
              onSubmitted: () => FocusScope.of(context).nextFocus(),
            )
          else
            AuthInput(
              icon: LucideIcons.mail,
              hintText: '请输入邮箱地址',
              controller: _emailCtrl,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
          // Send-code button + code input (only when panel requires verification)
          if (_config.emailVerifyRequired) ...[
            const SizedBox(height: 8),
            _SendCodeRow(
              countdown: _countdown,
              sending: _sendingCode,
              onTap: _sendCode,
            ),
            const SizedBox(height: 12),
            AuthInput(
              icon: LucideIcons.shieldCheck,
              hintText: '请输入邮件验证码',
              controller: _codeCtrl,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
          ],
          const SizedBox(height: 12),
          AuthInput(
            icon: LucideIcons.lock,
            hintText: '请输入密码',
            controller: _passwordCtrl,
            obscure: true,
            showRevealToggle: true,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 12),
          AuthInput(
            icon: LucideIcons.lock,
            hintText: '请再次输入密码',
            controller: _confirmCtrl,
            obscure: true,
            showRevealToggle: true,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 12),
          AuthInput(
            icon: LucideIcons.ticket,
            hintText: '邀请码（可选）',
            controller: _inviteCtrl,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          AuthCheckboxRow(
            value: _agree,
            label: '',
            onChanged: (v) => setState(() => _agree = v),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '我已阅读并同意 ',
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '服务条款',
                  style: AppTextStyles.button.copyWith(color: c.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: '注册',
            isLoading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: 20),
          AuthBottomJump(
            leadingText: '已有账号？',
            actionText: '登录',
            onTap: () => controller.goToAuthScreen(AuthScreen.login),
          ),
        ],
      ),
    );
  }
}

// ── Send-code row ─────────────────────────────────────────────────────────────

class _SendCodeRow extends StatelessWidget {
  const _SendCodeRow({
    required this.countdown,
    required this.sending,
    required this.onTap,
  });

  final int countdown;
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final disabled = sending || countdown > 0;

    String label;
    if (sending) {
      label = '发送中…';
    } else if (countdown > 0) {
      label = '重新发送 (${countdown}s)';
    } else {
      label = '发送验证码';
    }

    return Align(
      alignment: Alignment.centerRight,
      child: MouseRegion(
        cursor: disabled ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: disabled ? null : onTap,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: disabled ? c.surfaceMuted : c.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: disabled
                    ? c.softBorder
                    : c.primary.withValues(alpha: 0.3),
              ),
            ),
            child: sending
                ? SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: c.primary,
                    ),
                  )
                : Text(
                    label,
                    style: AppTextStyles.button.copyWith(
                      color: disabled ? c.textMuted : c.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Email suffix input ────────────────────────────────────────────────────────

class _EmailSuffixInput extends StatefulWidget {
  const _EmailSuffixInput({
    required this.prefixCtrl,
    required this.suffixes,
    required this.selected,
    required this.onSuffixChanged,
    this.onSubmitted,
  });

  final TextEditingController prefixCtrl;
  final List<String> suffixes;
  final String selected;
  final ValueChanged<String> onSuffixChanged;
  final VoidCallback? onSubmitted;

  @override
  State<_EmailSuffixInput> createState() => _EmailSuffixInputState();
}

class _EmailSuffixInputState extends State<_EmailSuffixInput> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _focused ? c.primary : const Color(0xFFCBD5E1),
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.mail, size: 17, color: c.iconMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.prefixCtrl,
              focusNode: _focusNode,
              onSubmitted: widget.onSubmitted != null ? (_) => widget.onSubmitted!() : null,
              style: AppTextStyles.input.copyWith(color: c.textPrimary),
              cursorColor: c.primary,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '邮箱前缀',
                hintStyle: AppTextStyles.input.copyWith(
                  color: c.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '@',
              style: AppTextStyles.input.copyWith(color: c.textMuted),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: widget.onSuffixChanged,
            tooltip: '',
            offset: const Offset(0, 40),
            itemBuilder: (_) => [
              for (final s in widget.suffixes)
                PopupMenuItem(
                  value: s,
                  height: 38,
                  child: Text(
                    s,
                    style: AppTextStyles.body.copyWith(
                      color: s == widget.selected ? c.primary : c.textPrimary,
                      fontWeight: s == widget.selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
            ],
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.selected,
                    style: AppTextStyles.input.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronDown, size: 14, color: c.iconMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
