abstract final class DataLoadErrorService {
  static String offlineMessage({required bool hasCachedNodes}) {
    return hasCachedNodes
        ? '服务器连接失败，已启用本地缓存模式，不影响已缓存节点使用。'
        : '当前无法连接服务器，且暂无本地节点缓存，请检查网络或联系客服。';
  }
}
