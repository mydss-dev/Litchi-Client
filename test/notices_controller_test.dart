import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/notices_controller.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

NoticeModel _notice(int id) =>
    NoticeModel(id: id, title: 't$id', content: 'c$id', createdAt: 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('flags unread when newest notice id exceeds last-seen', () async {
    final c = NoticesController();
    await c.loadLastSeen();
    expect(c.hasUnreadNotice, isFalse);

    c.setNotices([_notice(5), _notice(4)]);
    expect(c.hasUnreadNotice, isTrue);
  });

  test('markRead clears the unread flag', () async {
    final c = NoticesController();
    await c.loadLastSeen();
    c.setNotices([_notice(5)]);
    expect(c.hasUnreadNotice, isTrue);

    c.markRead();
    expect(c.hasUnreadNotice, isFalse);
  });

  test('reset empties the notice list', () {
    final c = NoticesController();
    c.setNotices([_notice(1)]);
    c.reset();
    expect(c.notices, isEmpty);
    expect(c.hasUnreadNotice, isFalse);
  });
}
