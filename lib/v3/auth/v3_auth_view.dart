import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/services/credentials_storage.dart';
import '../../shared/services/registration_email_policy.dart';
import '../../shared/services/secure_logger.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_toast.dart';

class V3AuthView extends StatefulWidget {
  const V3AuthView({super.key});
  @override
  State<V3AuthView> createState() => _V3AuthViewState();
}

class _V3AuthViewState extends State<V3AuthView> {
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    return ColoredBox(
      color: p.canvas,
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Row(children: [
          if (wide) const Expanded(flex: 11, child: _AuthBrandPanel()),
          Expanded(
            flex: wide ? 9 : 1,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 52 : 28, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!wide) ...[
                        V3BrandMark(boxSize: 34, labelColor: p.ink),
                        const SizedBox(height: 44),
                      ],
                      switch (controller.authScreen) {
                        AuthScreen.login => const _LoginForm(),
                        AuthScreen.register => const _RegisterForm(),
                        AuthScreen.forgotPassword => const _ForgotPasswordForm(),
                        AuthScreen.changePassword => const _LoginForm(),
                      },
                    ],
                  ),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      margin: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.hero,
        borderRadius: BorderRadius.circular(28), border: Border.all(color: p.line)),
      padding: const EdgeInsets.all(34),
      child: Stack(children: [
        const Align(alignment: Alignment.topLeft,
          child: V3BrandMark(boxSize: 34)),
        Align(alignment: Alignment.centerLeft,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 390),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v3Copy(context,
                  zh: 'A QUIETER WAY\nTO CROSS THE NET.',
                  en: 'A QUIETER WAY\nTO CROSS THE NET.',
                  tw: 'A QUIETER WAY\nTO CROSS THE NET.'),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: p.ink, fontSize: 42, height: .98)),
                const SizedBox(height: 20),
                Text(v3Copy(context,
                  zh: '选择线路、查看流量、确认连接状态，都在一个界面里完成。',
                  en: 'Choose a route, check usage and see connection status in one place.',
                  tw: '選擇線路、查看流量、確認連線狀態，都能在同一介面完成。'),
                  style: TextStyle(color: p.ink.withValues(alpha: .62),
                    fontSize: 13, height: 1.55)),
              ]))),
        Positioned(right: -34, bottom: -46,
          child: Container(width: 210, height: 210,
            decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: p.lychee.withValues(alpha: .65),
                width: 24)))),
        Positioned(right: 78, top: 90,
          child: Container(width: 12, height: 82,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                ? p.aqua : p.lycheeInk,
              borderRadius: BorderRadius.circular(12)))),
      ]),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _remember = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = AppScope.read(context);
      final message = ctrl.startupMessage;
      if (message == null || message.trim().isEmpty) return;
      ctrl.clearStartupMessage();
      V3Toast.show(context, message, type: V3ToastType.warning);
    });
  }

  Future<void> _loadSaved() async {
    try {
      final saved = await CredentialsStorage.load();
      if (saved == null || !mounted) return;
      if (_looksLikeJwt(saved.password)) {
        await CredentialsStorage.clearPassword();
        if (!mounted) return;
        setState(() => _email.text = saved.email);
        return;
      }
      setState(() { _email.text = saved.email; _password.text = saved.password; });
    } catch (error) {
      SecureLogger.warn('Login autofill failed', error);
    }
  }

  static bool _looksLikeJwt(String value) =>
      value.startsWith('eyJ') && value.split('.').length == 3;

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = v3Copy(context,
        zh: '请输入邮箱和密码', en: 'Enter your email and password',
        tw: '請輸入電子郵件與密碼'));
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final remember = _remember;
      await AppScope.read(context).loginWithCredentials(email, password,
        onAuthenticated: (_) async {
          if (remember) {
            await CredentialsStorage.save(email: email, password: password);
          } else {
            await CredentialsStorage.clear();
          }
        });
    } catch (error) {
      if (mounted) setState(() => _error = _authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final controller = AppScope.of(context);
    final registerOpen = controller.registerConfig.registerOpen;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(v3Copy(context, zh: '欢迎回来',
        en: 'Welcome back', tw: '歡迎回來'),
        style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 8),
      Text(v3Copy(context, zh: '登录后继续连接你的 Litchi 网络。',
        en: 'Sign in to continue using your Litchi network.',
        tw: '登入後繼續連線至你的 Litchi 網路。'),
        style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 32),
      _V3Field(controller: _email, label: 'EMAIL', hint: 'name@example.com',
        keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 16),
      _V3Field(controller: _password, label: 'PASSWORD', hint: '••••••••',
        obscureText: _obscure,
        trailing: IconButton(
          tooltip: _obscure ? v3Copy(context, zh: '显示密码',
              en: 'Show password', tw: '顯示密碼')
            : v3Copy(context, zh: '隐藏密码',
              en: 'Hide password', tw: '隱藏密碼'),
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility_off_rounded
              : Icons.visibility_rounded, size: 18, color: p.inkMuted)),
        onSubmitted: (_) => _login()),
      const SizedBox(height: 8),
      Row(children: [
        _RememberToggle(value: _remember,
          onChanged: (value) => setState(() => _remember = value)),
        const Spacer(),
        _InlineTextButton(label: v3Copy(context, zh: '忘记密码？',
          en: 'Forgot password?', tw: '忘記密碼？'),
          onPressed: () => controller.goToAuthScreen(AuthScreen.forgotPassword)),
      ]),
      if (_error != null) ...[
        const SizedBox(height: 14),
        Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 12)),
      ],
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, height: 52,
        child: FilledButton(onPressed: _busy ? null : _login,
          style: FilledButton.styleFrom(backgroundColor: p.lychee,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text(_busy ? v3Copy(context, zh: '正在登录…',
            en: 'Signing in…', tw: '正在登入…')
            : v3Copy(context, zh: '进入 Litchi',
              en: 'Sign in to Litchi', tw: '進入 Litchi')))),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(v3Copy(context, zh: '还没有账户？',
          en: 'No account?', tw: '還沒有帳戶？'),
          style: TextStyle(color: p.inkMuted, fontSize: 11)),
        if (registerOpen)
          _InlineTextButton(label: v3Copy(context, zh: '注册',
            en: 'Register', tw: '註冊'), accent: true,
            onPressed: () => controller.goToAuthScreen(AuthScreen.register))
        else Text(v3Copy(context, zh: ' 暂未开放注册',
          en: ' Registration is closed', tw: ' 暫未開放註冊'),
          style: TextStyle(color: p.inkMuted, fontSize: 11)),
      ]),
    ]);
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();
  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _email = TextEditingController();
  final _emailPrefix = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _inviteCode = TextEditingController();
  final _emailCode = TextEditingController();
  bool _busy = false;
  bool _sendingCode = false;
  bool _obscure = true;
  bool _configRefreshStarted = false;
  bool _codeSent = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _selectedDomain;
  String? _sentToEmail;
  String? _error;
  String? _notice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configRefreshStarted) return;
    _configRefreshStarted = true;
    unawaited(AppScope.read(context).refreshRegisterConfigCache());
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _email.dispose(); _emailPrefix.dispose(); _password.dispose();
    _confirm.dispose(); _inviteCode.dispose(); _emailCode.dispose();
    super.dispose();
  }

  bool _hasFixedDomains(List<String> suffixes) => suffixes.isNotEmpty &&
      suffixes.every((rule) {
        final value = rule.trim();
        return value.isNotEmpty && !value.startsWith('.') &&
            !value.startsWith('*.');
      });

  String _emailFor(List<String> suffixes) {
    if (!_hasFixedDomains(suffixes)) return _email.text.trim();
    final domains = RegistrationEmailPolicy.getSelectableDomains(suffixes);
    if (domains.isEmpty) return _email.text.trim();
    final selected = domains.contains(_selectedDomain)
        ? _selectedDomain! : domains.first;
    return '${_emailPrefix.text.trim()}@$selected';
  }

  bool _checkEmail(String email, List<String> suffixes) {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = v3Copy(context,
        zh: '请输入有效的邮箱地址', en: 'Enter a valid email address',
        tw: '請輸入有效的電子郵件地址'));
      return false;
    }
    if (RegistrationEmailPolicy.allows(email, suffixes)) return true;
    setState(() => _error = v3Copy(context,
      zh: '该邮箱后缀不在后台允许注册的名单中',
      en: 'This email domain is not allowed for registration',
      tw: '此電子郵件網域不在後台允許註冊的名單中'));
    return false;
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_cooldownSeconds > 0) _cooldownSeconds--;
        if (_cooldownSeconds == 0) timer.cancel();
      });
    });
  }

  Future<void> _sendCode() async {
    if (_sendingCode || _busy || _cooldownSeconds > 0 || _codeSent) return;
    final config = AppScope.read(context).registerConfig;
    if (!config.registerOpen || !config.emailVerifyRequired) return;
    final email = _emailFor(config.emailSuffixes);
    if (!_checkEmail(email, config.emailSuffixes)) return;
    setState(() { _sendingCode = true; _error = null; _notice = null; });
    try {
      await AppScope.read(context).api.sendEmailVerify(email);
      if (mounted) {
        setState(() {
          _codeSent = true;
          _sentToEmail = email;
          _cooldownSeconds = 60;
          _notice = v3Copy(context,
            zh: '验证码已发送，请查收邮箱',
            en: 'Verification code sent. Check your inbox.',
            tw: '驗證碼已寄出，請查收信箱');
        });
        _startCooldown();
      }
    } catch (error) {
      if (mounted) setState(() => _error = _authError(error));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  void _changeEmail() {
    if (!_codeSent || _busy) return;
    setState(() {
      _codeSent = false;
      _sentToEmail = null;
      _emailCode.clear();
      _notice = null;
      _error = null;
    });
  }

  Future<void> _register() async {
    if (_busy || _sendingCode) return;
    final config = AppScope.read(context).registerConfig;
    final email = _emailFor(config.emailSuffixes);
    final password = _password.text;
    final confirm = _confirm.text;
    final inviteCode = _inviteCode.text.trim();
    final emailCode = _emailCode.text.trim();
    if (!config.registerOpen) {
      setState(() => _error = v3Copy(context,
        zh: '后台暂未开放注册', en: 'Registration is currently closed',
        tw: '後台暫未開放註冊'));
      return;
    }
    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = v3Copy(context, zh: '请填写邮箱和密码',
        en: 'Enter your email and password', tw: '請填寫電子郵件與密碼'));
      return;
    }
    if (!_checkEmail(email, config.emailSuffixes)) return;
    if (password != confirm) {
      setState(() => _error = v3Copy(context,
        zh: '两次输入的密码不一致', en: 'Passwords do not match',
        tw: '兩次輸入的密碼不一致'));
      return;
    }
    if (config.emailVerifyRequired && emailCode.isEmpty) {
      setState(() => _error = v3Copy(context,
        zh: '请输入邮箱验证码', en: 'Enter email verification code',
        tw: '請輸入電子郵件驗證碼'));
      return;
    }
    if (config.emailVerifyRequired && _sentToEmail != null &&
        _sentToEmail!.toLowerCase() != email.toLowerCase()) {
      setState(() => _error = v3Copy(context,
        zh: '邮箱已变化，请重新发送验证码',
        en: 'Email changed. Send a new verification code.',
        tw: '電子郵件已變更，請重新寄送驗證碼'));
      return;
    }
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await AppScope.read(context).registerWithCredentials(
        email: email, password: password,
        passwordConfirmation: confirm,
        inviteCode: inviteCode.isEmpty ? null : inviteCode,
        emailCode: config.emailVerifyRequired && emailCode.isNotEmpty
            ? emailCode : null);
    } catch (error) {
      if (mounted) setState(() => _error = _authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final controller = AppScope.of(context);
    final config = controller.registerConfig;
    final emailVerifyRequired = config.emailVerifyRequired;
    final fixedDomains = _hasFixedDomains(config.emailSuffixes);
    final domains = RegistrationEmailPolicy.getSelectableDomains(
        config.emailSuffixes);
    final selectedDomain = domains.contains(_selectedDomain)
        ? _selectedDomain : (domains.isEmpty ? null : domains.first);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(v3Copy(context, zh: '创建账户', en: 'Create account', tw: '建立帳戶'),
        style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 8),
      Text(v3Copy(context, zh: '注册一个新的 Litchi 账户。',
        en: 'Register a new Litchi account.', tw: '註冊新的 Litchi 帳戶。'),
        style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 32),
      if (fixedDomains && selectedDomain != null)
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(flex: 3, child: _V3Field(
            controller: _emailPrefix,
            label: v3Copy(context, zh: '邮箱前缀',
              en: 'EMAIL NAME', tw: '電子郵件前綴'),
            hint: 'name', enabled: !_codeSent)),
          Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 17),
            child: Text('@', style: TextStyle(color: p.inkMuted))),
          Expanded(flex: 4, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v3Copy(context, zh: '邮箱后缀',
                en: 'DOMAIN', tw: '電子郵件後綴'),
                style: TextStyle(color: p.inkMuted, fontSize: 10,
                  fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.line)),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedDomain,
                  items: domains.map((domain) => DropdownMenuItem<String>(
                    value: domain, child: Text(domain,
                      maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _codeSent ? null : (value) {
                    if (value != null) setState(() => _selectedDomain = value);
                  },
                ))),
            ])),
        ])
      else
        _V3Field(controller: _email, label: 'EMAIL', hint: 'name@example.com',
          keyboardType: TextInputType.emailAddress, enabled: !_codeSent),
      if (config.emailSuffixes.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('${v3Copy(context,
          zh: '允许注册的邮箱后缀：', en: 'Allowed email suffixes: ',
          tw: '允許註冊的電子郵件後綴：')}${config.emailSuffixes.join('、')}',
          style: TextStyle(color: p.inkMuted, fontSize: 11)),
      ],
      if (_codeSent) ...[
        const SizedBox(height: 4),
        _InlineTextButton(label: v3Copy(context, zh: '更换邮箱',
          en: 'Change email', tw: '更換電子郵件'), onPressed: _changeEmail),
      ],
      const SizedBox(height: 16),
      _V3Field(controller: _password, label: 'PASSWORD', hint: '••••••••',
        obscureText: _obscure,
        trailing: IconButton(tooltip: _obscure
            ? v3Copy(context, zh: '显示密码', en: 'Show password', tw: '顯示密碼')
            : v3Copy(context, zh: '隐藏密码', en: 'Hide password', tw: '隱藏密碼'),
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility_off_rounded
            : Icons.visibility_rounded, size: 18, color: p.inkMuted))),
      const SizedBox(height: 16),
      _V3Field(controller: _confirm, label: 'CONFIRM PASSWORD', hint: '••••••••',
        obscureText: _obscure),
      const SizedBox(height: 16),
      _V3Field(controller: _inviteCode,
        label: v3Copy(context, zh: '邀请码（选填）',
          en: 'Invite code (optional)', tw: '邀請碼（選填）'),
        hint: v3Copy(context, zh: '如有邀请码可填写',
          en: 'Enter an invite code if you have one', tw: '如有邀請碼可填寫')),
      if (emailVerifyRequired) ...[
        const SizedBox(height: 16),
        _V3Field(controller: _emailCode,
          label: v3Copy(context, zh: '邮箱验证码',
            en: 'Email verification code', tw: '電子郵件驗證碼'),
          hint: v3Copy(context, zh: '6 位验证码',
            en: '6-digit code', tw: '6 位驗證碼'),
          keyboardType: TextInputType.number,
          trailing: _InlineTextButton(label: _sendingCode
            ? v3Copy(context, zh: '发送中…', en: 'Sending…', tw: '傳送中…')
            : _cooldownSeconds > 0
              ? '${_cooldownSeconds}s'
              : v3Copy(context, zh: '发送验证码',
                  en: 'Send code', tw: '傳送驗證碼'),
            onPressed: _sendingCode || _busy || _codeSent ||
                _cooldownSeconds > 0 || !config.registerOpen
                ? null : _sendCode)),
      ],
      if (!config.registerOpen) ...[
        const SizedBox(height: 14),
        Text(v3Copy(context, zh: '后台暂未开放注册',
          en: 'Registration is currently closed', tw: '後台暫未開放註冊'),
          style: TextStyle(color: p.dangerInk, fontSize: 12)),
      ],
      if (_error != null) ...[
        const SizedBox(height: 14),
        Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 12)),
      ],
      if (_notice != null) ...[
        const SizedBox(height: 14),
        Text(_notice!, style: TextStyle(color: p.successInk, fontSize: 12)),
      ],
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 52,
        child: FilledButton(onPressed: _busy || _sendingCode ||
            !config.registerOpen ? null : _register,
          style: FilledButton.styleFrom(backgroundColor: p.lychee,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text(_busy ? v3Copy(context,
            zh: '正在注册…', en: 'Registering…', tw: '正在註冊…')
            : v3Copy(context, zh: '创建账户',
              en: 'Create account', tw: '建立帳戶')))),
      const SizedBox(height: 18),
      Center(child: _InlineTextButton(label: v3Copy(context,
        zh: '已有账户？返回登录', en: 'Have an account? Sign in',
        tw: '已有帳戶？返回登入'),
        onPressed: () => controller.goToAuthScreen(AuthScreen.login))),
    ]);
  }
}

class _ForgotPasswordForm extends StatefulWidget {
  const _ForgotPasswordForm();
  @override
  State<_ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<_ForgotPasswordForm> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _sendingCode = false;
  bool _obscure = true;
  // Same 60s resend cooldown as the register form, so the endpoint cannot be
  // hammered and both flows behave identically.
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _email.dispose(); _code.dispose(); _password.dispose(); _confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_cooldownSeconds > 0) _cooldownSeconds--;
        if (_cooldownSeconds == 0) timer.cancel();
      });
    });
  }

  Future<void> _sendCode() async {
    if (_sendingCode || _cooldownSeconds > 0) return;
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = v3Copy(context, zh: '请先填写邮箱',
        en: 'Enter your email first', tw: '請先填寫電子郵件'));
      return;
    }
    setState(() { _sendingCode = true; _error = null; _notice = null; });
    try {
      await AppScope.read(context).api.sendEmailVerify(email,
        isForgetPassword: true);
      if (mounted) {
        setState(() {
          _cooldownSeconds = 60;
          _notice = v3Copy(context,
            zh: '验证码已发送，请查收邮箱',
            en: 'Verification code sent. Check your inbox.',
            tw: '驗證碼已寄出，請查收信箱');
        });
        _startCooldown();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _authError(error));
      }
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _reset() async {
    if (_busy) return;
    final email = _email.text.trim();
    final code = _code.text.trim();
    final password = _password.text;
    final confirm = _confirm.text;
    if (email.isEmpty || code.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = v3Copy(context, zh: '请完整填写所有字段',
        en: 'Fill in all fields', tw: '請完整填寫所有欄位'));
      return;
    }
    if (password != confirm) {
      setState(() => _error = v3Copy(context,
        zh: '两次输入的新密码不一致', en: 'New passwords do not match',
        tw: '兩次輸入的新密碼不一致'));
      return;
    }
    setState(() { _busy = true; _error = null; _notice = null; });
    try {
      await AppScope.read(context).api.resetPassword(
        email: email, emailCode: code, password: password,
        passwordConfirmation: confirm);
      if (!mounted) return;
      AppScope.read(context).goToAuthScreen(AuthScreen.login);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        v3Copy(context, zh: '密码已重置，请使用新密码登录',
          en: 'Password reset. Sign in with your new password.',
          tw: '密碼已重置，請使用新密碼登入'))));
    } catch (error) {
      if (mounted) setState(() => _error = _authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final controller = AppScope.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(v3Copy(context, zh: '找回密码',
        en: 'Reset password', tw: '找回密碼'),
        style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 8),
      Text(v3Copy(context, zh: '通过邮箱验证码重置你的密码。',
        en: 'Reset your password using an email verification code.',
        tw: '透過電子郵件驗證碼重置密碼。'),
        style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 32),
      _V3Field(controller: _email, label: 'EMAIL', hint: 'name@example.com',
        keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 16),
      _V3Field(controller: _code,
        label: v3Copy(context, zh: '邮箱验证码',
          en: 'Email verification code', tw: '電子郵件驗證碼'),
        hint: v3Copy(context, zh: '6 位验证码',
          en: '6-digit code', tw: '6 位驗證碼'),
        keyboardType: TextInputType.number,
        trailing: _InlineTextButton(label: _sendingCode
          ? v3Copy(context, zh: '发送中…', en: 'Sending…', tw: '傳送中…')
          : _cooldownSeconds > 0
            ? '${_cooldownSeconds}s'
            : v3Copy(context, zh: '发送验证码',
                en: 'Send code', tw: '傳送驗證碼'),
          onPressed: _sendingCode || _cooldownSeconds > 0
              ? null : _sendCode)),
      const SizedBox(height: 16),
      _V3Field(controller: _password,
        label: v3Copy(context, zh: '新密码', en: 'New password', tw: '新密碼'),
        hint: '••••••••', obscureText: _obscure,
        trailing: IconButton(tooltip: _obscure
            ? v3Copy(context, zh: '显示密码', en: 'Show password', tw: '顯示密碼')
            : v3Copy(context, zh: '隐藏密码', en: 'Hide password', tw: '隱藏密碼'),
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility_off_rounded
            : Icons.visibility_rounded, size: 18, color: p.inkMuted))),
      const SizedBox(height: 16),
      _V3Field(controller: _confirm,
        label: v3Copy(context, zh: '确认新密码',
          en: 'Confirm new password', tw: '確認新密碼'),
        hint: '••••••••', obscureText: _obscure),
      if (_error != null) ...[
        const SizedBox(height: 14),
        Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 12)),
      ],
      if (_notice != null) ...[
        const SizedBox(height: 14),
        Text(_notice!, style: TextStyle(color: p.successInk, fontSize: 12)),
      ],
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, height: 52,
        child: FilledButton(onPressed: _busy ? null : _reset,
          style: FilledButton.styleFrom(backgroundColor: p.lychee,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text(_busy ? v3Copy(context,
            zh: '正在重置…', en: 'Resetting…', tw: '正在重置…')
            : v3Copy(context, zh: '重置密码',
              en: 'Reset password', tw: '重置密碼')))),
      const SizedBox(height: 18),
      Center(child: _InlineTextButton(label: v3Copy(context,
        zh: '返回登录', en: 'Back to sign in', tw: '返回登入'),
        onPressed: () => controller.goToAuthScreen(AuthScreen.login))),
    ]);
  }
}

class _RememberToggle extends StatelessWidget {
  const _RememberToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return InkWell(onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(padding: const EdgeInsets.symmetric(
          vertical: 4, horizontal: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 18, height: 18,
            child: Checkbox(value: value,
              onChanged: (next) => onChanged(next ?? false),
              activeColor: p.lychee, side: BorderSide(color: p.line),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact)),
          const SizedBox(width: 8),
          Text(v3Copy(context, zh: '记住账号密码',
            en: 'Remember credentials', tw: '記住帳號密碼'),
            style: TextStyle(color: p.inkMuted, fontSize: 11)),
        ])));
  }
}

class _InlineTextButton extends StatelessWidget {
  const _InlineTextButton({required this.label, required this.onPressed,
    this.accent = false});
  final String label;
  final VoidCallback? onPressed;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return TextButton(onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: accent ? p.lycheeInk : p.inkMuted,
        padding: EdgeInsets.zero, minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      child: Text(label));
  }
}

class _V3Field extends StatelessWidget {
  const _V3Field({required this.controller, required this.label,
    required this.hint, this.keyboardType, this.obscureText = false,
    this.trailing, this.onSubmitted, this.enabled = true});
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: p.inkMuted, fontSize: 10,
        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      const SizedBox(height: 8),
      TextField(controller: controller, keyboardType: keyboardType,
        obscureText: obscureText, onSubmitted: onSubmitted, enabled: enabled,
        decoration: InputDecoration(hintText: hint, suffixIcon: trailing,
          filled: true, fillColor: p.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: p.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: p.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: p.lychee, width: 1.5)))),
    ]);
  }
}

String _authError(Object error) => error.toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '');