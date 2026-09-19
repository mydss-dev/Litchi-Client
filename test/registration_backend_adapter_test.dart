import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/panel_backend.dart';
import 'package:litchi_client/shared/services/panel_backend_adapter.dart';

void main() {
  const path = '/passport/comm/sendEmailVerify';
  test('standard panel marks registration email code as non-reset', () {
    final body = const PanelBackendAdapter(PanelType.v2board)
        .preparePostData(path, {'email': 'a@example.com'});
    expect(body, {'email': 'a@example.com', 'isForgetPassword': false});
  });

  test('Xiao-V2Board maps registration and reset flags to isforget', () {
    const adapter = PanelBackendAdapter(PanelType.xiaoV2board);
    expect(adapter.preparePostData(path, {'email': 'a@example.com'}),
        {'email': 'a@example.com', 'isforget': 0});
    expect(adapter.preparePostData(path, {
      'email': 'a@example.com', 'isForgetPassword': true,
    }), {'email': 'a@example.com', 'isforget': 1});
  });

  test('does not add email flags to unrelated endpoints', () {
    expect(const PanelBackendAdapter(PanelType.v2board)
        .preparePostData('/passport/auth/login', {'email': 'a@example.com'}),
        {'email': 'a@example.com'});
  });
}
