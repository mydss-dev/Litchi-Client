import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/data_load_error_service.dart';

void main() {
  test('returns cache-mode message when local nodes exist', () {
    expect(
      DataLoadErrorService.offlineMessage(hasCachedNodes: true),
      '服务器连接失败，已启用本地缓存模式，不影响已缓存节点使用。',
    );
  });

  test('returns blocking offline message when there are no local nodes', () {
    expect(
      DataLoadErrorService.offlineMessage(hasCachedNodes: false),
      '当前无法连接服务器，且暂无本地节点缓存，请检查网络或联系客服。',
    );
  });
}
