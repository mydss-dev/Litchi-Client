import 'package:flutter/foundation.dart';

import '../shared/models/api_models.dart';
import '../shared/services/notice_cache_service.dart';
import '../shared/services/settings_service.dart';

/// Owns the notices domain: the notice list, the last-seen marker that drives
/// the unread badge, and a best-effort disk cache so the banner renders
/// instantly instead of waiting on the panel's `/user/notice/fetch` call.
/// Extracted from [AppController].
class NoticesController extends ChangeNotifier {
  List<NoticeModel> _notices = [];
  int _lastSeenNoticeId = 0;
  bool _isLoading = false;

  List<NoticeModel> get notices => _notices;
  bool get isLoading => _isLoading;
  bool get hasUnreadNotice =>
      _notices.isNotEmpty && _notices.first.id > _lastSeenNoticeId;

  /// Loads the persisted last-seen id. Call once during app init.
  Future<void> loadLastSeen() async {
    _lastSeenNoticeId = await SettingsService.loadLastSeenNoticeId();
  }

  /// Pre-populates the banner from the previous fetch's cache. Does nothing
  /// when notices are already present (a fresh fetch won earlier).
  Future<void> loadCached() async {
    final cached = await NoticeCacheService.load();
    if (cached.isEmpty || _notices.isNotEmpty) return;
    _notices = cached;
    notifyListeners();
  }

  /// Shows the skeleton in the banner slot while a fetch is in flight and
  /// there is nothing cached to display yet.
  void setLoading(bool loading) {
    if (_isLoading == loading) return;
    _isLoading = loading;
    notifyListeners();
  }

  void setNotices(List<NoticeModel> notices) {
    _notices = notices;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveCache() => NoticeCacheService.save(_notices);

  void markRead() {
    if (_notices.isEmpty) return;
    _lastSeenNoticeId = _notices.first.id;
    SettingsService.setLastSeenNoticeId(_lastSeenNoticeId);
    notifyListeners();
  }

  void reset() {
    if (_notices.isEmpty && !_isLoading) return;
    _notices = [];
    _isLoading = false;
    notifyListeners();
  }
}
