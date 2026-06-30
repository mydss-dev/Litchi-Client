import '../../l10n/generated/app_localizations.dart';

class AppErrorMessageService {
  AppErrorMessageService._();

  static final _han = RegExp(r'[\u3400-\u9fff]');

  static String userFacing(Object? error, AppLocalizations l10n) {
    final raw = _clean(error?.toString() ?? '');
    if (raw.isEmpty) return l10n.requestFailed;

    final lower = raw.toLowerCase();

    if (_hasAny(lower, const [
      'invalid credentials',
      'incorrect password',
      'wrong password',
      '邮箱或密码错误',
      '账号或密码错误',
      '密码错误',
    ])) {
      return l10n.invalidCredentialsError;
    }
    if (_hasAny(lower, const [
      'invalid verification code',
      'verification code is invalid',
      '验证码错误',
      '验证码无效',
    ])) {
      return l10n.invalidVerificationCodeError;
    }
    if (_hasAny(lower, const [
      'account is disabled',
      'account disabled',
      '账户已禁用',
      '账号已封禁',
    ])) {
      return l10n.accountDisabledError;
    }
    if (_hasAny(lower, const [
      'unauthenticated',
      'unauthorized',
      '登录已过期',
      '未登录',
    ])) {
      return l10n.sessionExpiredError;
    }
    if (_hasAny(lower, const [
      'too many attempts',
      'too many requests',
      '操作太频繁',
      '请求过于频繁',
    ])) {
      return l10n.tooManyRequestsError;
    }
    if (_hasAny(lower, const [
      'the given data was invalid',
      '提交内容有误',
      'validation',
    ])) {
      return l10n.invalidSubmissionError;
    }
    if (_hasAny(lower, const [
      'connection timeout',
      'receive timeout',
      'send timeout',
      'timed out',
      '连接超时',
      '请求超时',
    ])) {
      return l10n.connectionTimeoutError;
    }
    if (_hasAny(lower, const [
      'connection refused',
      'connection error',
      'failed host lookup',
      'network is unreachable',
      '无法连接到服务器',
      '无法连接服务器',
    ])) {
      return l10n.cannotConnectServerError;
    }
    if (_hasAny(lower, const [
      'server error',
      'server temporarily unavailable',
      '服务器暂时不可用',
    ])) {
      return l10n.serverUnavailableError;
    }
    if (_hasAny(lower, const [
      'response format',
      'invalid response',
      '响应格式异常',
      '数据格式异常',
    ])) {
      return l10n.invalidServerResponseError;
    }
    if (_hasAny(lower, const ['unsafe subscription', '订阅地址不安全'])) {
      return l10n.unsafeSubscriptionError;
    }
    if (_hasAny(lower, const [
      'configure server',
      'server address',
      '配置服务器地址',
    ])) {
      return l10n.serverNotConfiguredError;
    }
    if (_hasAny(lower, const [
      'sha-256',
      'sha256',
      'checksum',
      '校验失败',
      '文件可能已损坏',
    ])) {
      return l10n.installerVerificationError;
    }
    if (_hasAny(lower, const ['download failed', '下载失败'])) {
      return l10n.updateDownloadError;
    }
    if (_hasAny(lower, const ['network request failed', '网络请求失败'])) {
      return l10n.networkRequestError;
    }

    // Simplified Chinese is the source language for legacy backend and runtime
    // messages. Other locales receive a safe localized fallback instead of a
    // mixed-language or overly technical error.
    if (l10n.localeName != 'zh' && _han.hasMatch(raw)) {
      return l10n.unexpectedError;
    }
    return raw;
  }

  static String _clean(String value) => value.trim().replaceFirst(
    RegExp(r'^(?:ApiException|Exception|StateError):\s*'),
    '',
  );

  static bool _hasAny(String value, List<String> needles) =>
      needles.any(value.contains);
}
