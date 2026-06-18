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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncConfig(AppScope.of(context).registerConfig);
  }

  void _syncConfig(RegisterConfig config) {
    if (_sameConfig(_config, config)) return;
    _config = config;
    if (config.emailSuffixes.isEmpty) {
      _selectedSuffix = '';
    } else if (!config.emailSuffixes.contains(_selectedSuffix)) {
      _selectedSuffix = config.emailSuffixes.first;
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

  bool _sameConfig(RegisterConfig a, RegisterConfig b) {
    if (a.emailVerifyRequired != b.emailVerifyRequired) return false;
    if (a.emailSuffixes.length != b.emailSuffixes.length) return false;
    for (var i = 0; i < a.emailSuffixes.length; i++) {
      if (a.emailSuffixes[i] != b.emailSuffixes[i]) return false;
    }
    return true;
  }

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
        final message = e.toString().replaceFirst('ApiException: ', '');
        AppToast.show(context, message, type: AppToastType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = AppScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            label: '邮箱',
            requiredMark: true,
            hintText: '请输入邮箱地址',
            controller: _emailCtrl,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
        // Send-code button + code input (only when panel requires verification)
        if (_config.emailVerifyRequired) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AuthInput(
                  icon: LucideIcons.shieldCheck,
                  label: '验证码',
                  requiredMark: true,
                  hintText: '请输入邮件验证码',
                  controller: _codeCtrl,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
              ),
              const SizedBox(width: 10),
              _SendCodeRow(
                countdown: _countdown,
                sending: _sendingCode,
                onTap: _sendCode,
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        AuthInput(
          icon: LucideIcons.lock,
          label: '密码',
          requiredMark: true,
          hintText: '请输入密码',
          controller: _passwordCtrl,
          obscure: true,
          showRevealToggle: true,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 10),
        AuthInput(
          icon: LucideIcons.lock,
          label: '确认密码',
          requiredMark: true,
          hintText: '请再次输入密码',
          controller: _confirmCtrl,
          obscure: true,
          showRevealToggle: true,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        ),
        const SizedBox(height: 10),
        AuthInput(
          icon: LucideIcons.ticket,
          label: '邀请码',
          hintText: '邀请码（可选）',
          controller: _inviteCtrl,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 14),
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
        const SizedBox(height: 18),
        AuthPrimaryButton(label: '注册', isLoading: _loading, onPressed: _submit),
        const SizedBox(height: 16),
        AuthBottomJump(
          leadingText: '已有账号？',
          actionText: '登录',
          onTap: () => controller.goToAuthScreen(AuthScreen.login),
        ),
      ],
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

    return SizedBox(
      width: 112,
      height: 50,
      child: MouseRegion(
        cursor: disabled ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: disabled ? null : onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: disabled ? c.surfaceMuted : c.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: disabled ? c.softBorder : c.primary),
            ),
            child: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.button.copyWith(
                      color: disabled ? c.textMuted : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
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
  final _suffixLink = LayerLink();
  OverlayEntry? _suffixOverlay;
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
    _hideSuffixDropdown();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    final input = Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _focused ? c.primary : c.softBorder,
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
              onSubmitted: widget.onSubmitted != null
                  ? (_) => widget.onSubmitted!()
                  : null,
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
            padding: const EdgeInsets.only(left: 4, right: 3),
            child: Text(
              '@',
              style: AppTextStyles.input.copyWith(color: c.textMuted),
            ),
          ),
          CompositedTransformTarget(
            link: _suffixLink,
            child: GestureDetector(
              onTap: _toggleSuffixDropdown,
              behavior: HitTestBehavior.opaque,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.only(left: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 1, height: 20, color: c.softBorder),
                      const SizedBox(width: 7),
                      Text(
                        widget.selected,
                        style: AppTextStyles.input.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevronDown,
                        size: 15,
                        color: c.iconMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '邮箱',
              style: AppTextStyles.caption.copyWith(
                color: c.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: AppTextStyles.caption.copyWith(
                color: c.danger,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        input,
      ],
    );
  }

  void _toggleSuffixDropdown() {
    if (_suffixOverlay != null) {
      _hideSuffixDropdown();
      return;
    }
    _showSuffixDropdown();
  }

  void _hideSuffixDropdown() {
    _suffixOverlay?.remove();
    _suffixOverlay = null;
  }

  void _showSuffixDropdown() {
    final c = AppColors.of(context);
    _suffixOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideSuffixDropdown,
              ),
            ),
            CompositedTransformFollower(
              link: _suffixLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 8),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 148,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.cardBg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: c.softBorder),
                    boxShadow: [
                      BoxShadow(
                        color: c.shadow.withValues(alpha: 0.18),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final suffix in widget.suffixes) ...[
                        _EmailSuffixOption(
                          suffix: suffix,
                          selected: suffix == widget.selected,
                          compact: true,
                          onTap: () {
                            widget.onSuffixChanged(suffix);
                            _hideSuffixDropdown();
                          },
                        ),
                        if (suffix != widget.suffixes.last)
                          const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_suffixOverlay!);
  }
}

class _EmailSuffixOption extends StatelessWidget {
  const _EmailSuffixOption({
    required this.suffix,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String suffix;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: compact ? 40 : 48,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
        decoration: BoxDecoration(
          color: selected ? c.primarySoft : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                suffix,
                style: AppTextStyles.body.copyWith(
                  color: selected ? c.primary : c.textPrimary,
                  fontSize: compact ? 14 : null,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (selected) Icon(LucideIcons.check, color: c.primary, size: 16),
          ],
        ),
      ),
    );
  }
}
