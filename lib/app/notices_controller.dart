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
  Set<int> _seenPopupIds = {};
  bool _isLoading = false;

  List<NoticeModel> get notices => _notices;
  bool get isLoading => _isLoading;
  bool get hasUnreadNotice =>
      _notices.isNotEmpty && _notices.first.id > _lastSeenNoticeId;

  /// Must-read notices (tagged `弹窗`) the user has not dismissed yet.
  List<NoticeModel> get pendingPopups => _notices
      .where((n) => n.isPopup && !_seenPopupIds.contains(n.id))
      .toList();

  /// Loads persisted seen-state. Call once during app init.
  Future<void> loadLastSeen() async {
    _lastSeenNoticeId = await SettingsService.loadLastSeenNoticeId();
    _seenPopupIds = await SettingsService.loadSeenPopupNoticeIds();
  }

  /// Pre-populates the banner from the previous fetch's cache. Does nothing
  /// when notices are already present (a fresh fetch won earlier).
  Future<void> loadCached() async {
    final cached = await NoticeCacheService.load();
    if (cached.isEmpty || _notices.isNotEmpty) return;
    _notices = _newestFirst(cached);
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
    _notices = _newestFirst(notices);
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

  /// Records [id] as a dismissed popup so it is never shown again.
  void markPopupSeen(int id) {
    if (_seenPopupIds.contains(id)) return;
    _seenPopupIds.add(id);
    SettingsService.saveSeenPopupNoticeIds(_seenPopupIds);
    notifyListeners();
  }

  void reset() {
    if (_notices.isEmpty && !_isLoading) return;
    _notices = [];
    _isLoading = false;
    notifyListeners();
  }

  /// Orders notices newest-first (highest id first).
  ///
  /// The panel returns announcements in ascending-id order (oldest first), but
  /// the carousel shows `notices[0]` first and the unread badge treats
  /// `notices.first` as the newest, so the list is re-ordered on the way in.
  /// Sorted here (rather than at the API boundary) so the invariant holds for
  /// both the fresh-fetch and cached-load paths.
  static List<NoticeModel> _newestFirst(List<NoticeModel> notices) {
    final sorted = List<NoticeModel>.of(notices);
    sorted.sort((a, b) {
      final byId = b.id.compareTo(a.id);
      if (byId != 0) return byId;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }
}
