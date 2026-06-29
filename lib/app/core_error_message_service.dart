abstract final class CoreErrorMessageService {
  static const noAvailableNodes = '没有可用节点，请刷新节点列表后重试';
  static const configBuildFailed = '生成配置失败，请选择其他节点后重试';
  static const restartClient = '连接失败，请重启客户端后重试';
  static const missingCore = '连接失败，请检查 mihomo 核心是否存在';
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
  static String userFacing(String error) {
    final raw = error.trim();
    if (raw.isEmpty) return genericConnectionFailure;

    final lower = raw.toLowerCase();
    if (lower.contains('proxy') && lower.contains('not found')) {
      return invalidNodeConfig;
    }
    if (lower.contains('parse config') || lower.contains('config error')) {
      return configBuildFailed;
    }
    if (lower.contains('access denied') ||
        lower.contains('permission denied')) {
      return permissionDenied;
    }

    final looksLikeRawLog =
        raw.length > 120 ||
        raw.contains('\n') ||
        lower.contains('time=') ||
        lower.contains('level=') ||
        lower.contains('msg=');
    return looksLikeRawLog ? genericConnectionFailure : raw;
  }
}
