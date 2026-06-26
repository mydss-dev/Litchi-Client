abstract final class CoreErrorMessageService {
  static const noAvailableNodes = '没有可用节点，请刷新节点列表后重试';
  static const configBuildFailed = '生成配置失败，客户端文件可能不完整，请重新安装后重试';
  static const restartClient = '连接失败，请重启客户端后重试';
  static const missingSingBox = '连接失败，请检查 sing-box.exe 是否存在';
  static const permissionDenied = '权限不足，请以管理员身份运行客户端';
  static const androidStartFailed = 'Android 核心启动失败';

  static String windowsStartException(Object error) {
    final raw = '$error';
    if (raw.contains('Access') || raw.contains('denied')) {
      return permissionDenied;
    }
    return restartClient;
  }

  static String processStartFailure(String lastError) {
    return lastError.isNotEmpty ? lastError : missingSingBox;
  }

  static String androidStartFailure(String lastError) {
    return lastError.isNotEmpty ? lastError : androidStartFailed;
  }
}
