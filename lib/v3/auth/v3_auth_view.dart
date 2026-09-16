import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';

class V3AuthView extends StatefulWidget {
  const V3AuthView({super.key});

  @override
  State<V3AuthView> createState() => _V3AuthViewState();
}

class _V3AuthViewState extends State<V3AuthView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = '请输入邮箱和密码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).loginWithCredentials(email, password);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return ColoredBox(
      color: p.canvas,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return Row(
            children: [
              if (wide)
                Expanded(
                  flex: 11,
                  child: Container(
                    margin: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: p.hero,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: p.line),
                    ),
                    padding: const EdgeInsets.all(34),
                    child: Stack(
                      children: [
                        const Align(
                          alignment: Alignment.topLeft,
                          child: V3BrandMark(boxSize: 34),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 390),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'A QUIETER WAY\nTO CROSS THE NET.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displayLarge
                                      ?.copyWith(
                                        color: p.ink,
                                        fontSize: 42,
                                        height: 0.98,
                                      ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  '选择线路、查看流量、确认连接状态，都在一个界面里完成。',
                                  style: TextStyle(
                                    color: p.ink.withValues(alpha: 0.62),
                                    fontSize: 13,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: -34,
                          bottom: -46,
                          child: Container(
                            width: 210,
                            height: 210,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: p.lychee.withValues(alpha: 0.65),
                                width: 24,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 78,
                          top: 90,
                          child: Container(
                            width: 12,
                            height: 82,
                            decoration: BoxDecoration(
                              // Aqua is tuned against the near-black the brand
                              // block used to be; on the light one it lands at
                              // 1.5:1 and reads as a smudge. The brand ink
                              // carries the same accent shape there.
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? p.aqua
                                  : p.lycheeInk,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                flex: wide ? 9 : 1,
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 52 : 28,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!wide) ...[
                            V3BrandMark(boxSize: 34, labelColor: p.ink),
                            const SizedBox(height: 44),
                          ],
                          Text(
                            '欢迎回来',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '登录后继续连接你的 Litchi 网络。',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 32),
                          _V3Field(
                            controller: _email,
                            label: 'EMAIL',
                            hint: 'name@example.com',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _V3Field(
                            controller: _password,
                            label: 'PASSWORD',
                            hint: '••••••••',
                            obscureText: _obscure,
                            trailing: IconButton(
                              tooltip: _obscure ? '显示密码' : '隐藏密码',
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 18,
                                color: p.inkMuted,
                              ),
                            ),
                            onSubmitted: (_) => _login(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: p.dangerInk,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: _busy ? null : _login,
                              style: FilledButton.styleFrom(
                                backgroundColor: p.lychee,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(_busy ? '正在登录…' : '进入 Litchi'),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '登录遇到问题？请联系你的服务商。',
                            style: TextStyle(
                              color: p.inkMuted,
                              fontSize: 10,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _V3Field extends StatelessWidget {
  const _V3Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.trailing,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? trailing;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: p.inkMuted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: trailing,
            filled: true,
            fillColor: p.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: p.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: p.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: p.lychee, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
