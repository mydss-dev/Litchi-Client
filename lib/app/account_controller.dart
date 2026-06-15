import 'package:flutter/foundation.dart';

import '../shared/models/app_models.dart';
import '../shared/services/panel_api.dart';

/// Owns the account domain: the user profile and traffic totals (both sourced
/// from the user-info API) plus the user-settings update action. Extracted from
/// [AppController].
class AccountController extends ChangeNotifier {
  AccountController(this._api);

  final PanelApi _api;

  static const _emptyUser = UserModel(
    name: '',
    plan: '',
    avatarLetter: '',
    expiry: '',
  );
  static const _emptyTraffic = TrafficModel(totalGb: 0, usedGb: 0, remainGb: 0);

  UserModel _user = _emptyUser;
  TrafficModel _traffic = _emptyTraffic;

  UserModel get user => _user;
  TrafficModel get traffic => _traffic;

  /// Applies user / traffic from a data snapshot (null fields are skipped).
  void applySnapshot({UserModel? user, TrafficModel? traffic}) {
    var changed = false;
    if (user != null) {
      _user = user;
      changed = true;
    }
    if (traffic != null) {
      _traffic = traffic;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void setTraffic(TrafficModel? traffic) {
    if (traffic == null) return;
    _traffic = traffic;
    notifyListeners();
  }

  void reset() {
    _user = _emptyUser;
    _traffic = _emptyTraffic;
    notifyListeners();
  }

  /// Optimistically applies the reminder/auto-renew toggles, then persists.
  /// Rolls back and returns an error message if the API call fails.
  Future<String?> updateUserSettings({
    required bool remindExpire,
    required bool remindTraffic,
    required bool autoRenewal,
  }) async {
    final previous = _user;
    _user = _user.copyWith(
      remindExpire: remindExpire,
      remindTraffic: remindTraffic,
      autoRenewal: autoRenewal,
    );
    notifyListeners();

    try {
      await _api.updateUserSettings(
        remindExpire: remindExpire,
        remindTraffic: remindTraffic,
        autoRenewal: autoRenewal,
      );
      return null;
    } catch (e) {
      _user = previous;
      notifyListeners();
      return e.toString().replaceFirst('ApiException: ', '');
    }
  }
}
