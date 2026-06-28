abstract final class CoreErrorMessageService {
  static const noAvailableNodes = '没有可用节点，请刷新节点列表后重试';
  static const configBuildFailed = '生成配置失败，请选择其他节点后重试';
  static const restartClient = '连接失败，请重启客户端后重试';
  static const missingCore = '连接失败，请检查 mihomo 核心是否存在';
  static const permissionDenied = '权限不足，请以管理员身份运行客户端';
  static const androidStartFailed = 'Android 核心启动失败';
  static const unexpectedCoreExit = '核心异常退出，连接已断开，请重新连接';

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
}
