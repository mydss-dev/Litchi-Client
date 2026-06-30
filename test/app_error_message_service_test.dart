import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/l10n/generated/app_localizations_en.dart';
import 'package:litchi_client/l10n/generated/app_localizations_zh.dart';
import 'package:litchi_client/shared/services/app_error_message_service.dart';

void main() {
  final en = AppLocalizationsEn();
  final zh = AppLocalizationsZh();
  final zhTw = AppLocalizationsZhTw();

  test('maps common API and network errors', () {
    expect(
      AppErrorMessageService.userFacing('ApiException: 登录已过期，请重新登录', en),
      en.sessionExpiredError,
    );
    expect(
      AppErrorMessageService.userFacing('Connection timed out', zhTw),
      zhTw.connectionTimeoutError,
    );
    expect(
      AppErrorMessageService.userFacing('邮箱或密码错误', en),
      en.invalidCredentialsError,
    );
  });

  test('hides untranslated Chinese errors outside simplified Chinese', () {
    const raw = '服务端返回了一个尚未识别的错误';
    expect(AppErrorMessageService.userFacing(raw, en), en.unexpectedError);
    expect(AppErrorMessageService.userFacing(raw, zhTw), zhTw.unexpectedError);
    expect(AppErrorMessageService.userFacing(raw, zh), raw);
  });

  test('preserves useful unknown errors without mixed-language fallback', () {
    const raw = 'Payment provider rejected the request';
    expect(AppErrorMessageService.userFacing(raw, en), raw);
    expect(AppErrorMessageService.userFacing('Exception: $raw', en), raw);
  });
}
