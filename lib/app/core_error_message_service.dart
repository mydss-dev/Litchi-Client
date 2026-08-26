import '../l10n/generated/app_localizations.dart';

abstract final class CoreErrorMessageService {
  static const noAvailableNodes = '没有可用节点，请刷新节点列表后重试';
  static const configBuildFailed = '生成配置失败，请选择其他节点后重试';
  static const restartClient = '连接失败，请重启客户端后重试';
  static const proxyPortUnavailable = '本地代理端口启动失败，请关闭其他代理软件后重试';
  static const missingCore = '连接失败，请检查 sing-box 核心是否存在';
  static const permissionDenied = '权限不足，请以管理员身份运行客户端';
  static const tunInterfaceUnavailable = 'TUN 虚拟网卡启动失败，请以管理员身份运行或重试';
  static const tunKillSwitchUnavailable = 'TUN 中断保护启动失败，已停止连接以避免流量泄漏';
  static const androidStartFailed = 'Android 核心启动失败';
  static const unexpectedCoreExit = '核心异常退出，连接已断开，请重新连接';
  static const invalidNodeConfig = '当前节点配置无效，请切换节点后重试';
  static const genericConnectionFailure = '连接失败，请切换节点或稍后重试';

  static String windowsStartException(Object error) {
    final raw = '$error';
    if (raw.contains('Access') || raw.contains('denied')) {
      return permissionDenied;
    }
    return restartClient;
  }

  static String processStartFailure(String lastError) {
    return lastError.isNotEmpty ? lastError : missingCore;
  }

  static String androidStartFailure(String lastError) {
    return lastError.isNotEmpty ? lastError : androidStartFailed;
  }

  /// Converts low-level core output into a short message suitable for UI.
  static String userFacing(String error, {AppLocalizations? l10n}) {
    final raw = error.trim();
    if (raw.isEmpty) {
      return l10n?.genericConnectionFailureError ?? genericConnectionFailure;
    }

    if (l10n != null) {
      final exact = switch (raw) {
        noAvailableNodes => l10n.noAvailableNodes,
        configBuildFailed => l10n.configBuildFailedError,
        restartClient => l10n.restartClientError,
        proxyPortUnavailable => l10n.proxyPortUnavailableError,
        missingCore => l10n.missingCoreError,
        permissionDenied => l10n.permissionDeniedError,
        tunInterfaceUnavailable => l10n.tunInterfaceUnavailableError,
        tunKillSwitchUnavailable => l10n.tunKillSwitchUnavailableError,
        androidStartFailed => l10n.androidStartFailedError,
        unexpectedCoreExit => l10n.unexpectedCoreExitError,
        invalidNodeConfig => l10n.invalidNodeConfigError,
        genericConnectionFailure => l10n.genericConnectionFailureError,
        _ => null,
      };
      if (exact != null) return exact;
    }

    final lower = raw.toLowerCase();
    if (lower.contains('proxy') && lower.contains('not found')) {
      return l10n?.invalidNodeConfigError ?? invalidNodeConfig;
    }
    if (lower.contains('parse config') || lower.contains('config error')) {
      return l10n?.configBuildFailedError ?? configBuildFailed;
    }
    if (lower.contains('access denied') ||
        lower.contains('permission denied')) {
      return l10n?.permissionDeniedError ?? permissionDenied;
    }

    final looksLikeRawLog =
        raw.length > 120 ||
        raw.contains('\n') ||
        lower.contains('time=') ||
        lower.contains('level=') ||
        lower.contains('msg=');
    return looksLikeRawLog
        ? (l10n?.genericConnectionFailureError ?? genericConnectionFailure)
        : raw;
  }
}
