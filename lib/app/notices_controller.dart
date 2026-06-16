import 'package:flutter/foundation.dart';

import '../shared/models/api_models.dart';
import '../shared/services/settings_service.dart';

/// Owns the notices domain: the notice list and the last-seen marker that drives
/// the unread badge. Extracted from [AppController].
class NoticesController extends ChangeNotifier {
  List<NoticeModel> _notices = [];
  int _lastSeenNoticeId = 0;

  List<NoticeModel> get notices => _notices;
  bool get hasUnreadNotice =>
      _notices.isNotEmpty && _notices.first.id > _lastSeenNoticeId;

  /// Loads the persisted last-seen id. Call once during app init.
  Future<void> loadLastSeen() async {
    _lastSeenNoticeId = await SettingsService.loadLastSeenNoticeId();
  }

  void setNotices(List<NoticeModel> notices) {
    _notices = notices;
    notifyListeners();
  }

  void markRead() {
    if (_notices.isEmpty) return;
    _lastSeenNoticeId = _notices.first.id;
    SettingsService.setLastSeenNoticeId(_lastSeenNoticeId);
    notifyListeners();
  }

  void reset() {
    if (_notices.isEmpty) return;
    _notices = [];
    notifyListeners();
  }
}
