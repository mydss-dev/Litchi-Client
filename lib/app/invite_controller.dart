import 'package:flutter/foundation.dart';

import '../shared/models/app_models.dart';
import '../shared/models/invite_data_state.dart';
import '../shared/services/invite_link_service.dart';
import '../shared/services/panel_api.dart';

/// Owns the invite domain: invite codes, the share link, and code creation.
/// Extracted from [AppController]; link normalization lives here so the
/// controller is the single authority for invite link shape.
class InviteController extends ChangeNotifier {
  InviteController(this._api, this._refresh);

  final PanelApi _api;
  final Future<void> Function() _refresh;

  InviteDataState _state = const InviteDataState();
  InviteDataState get state => _state;

  List<InviteCodeModel> get codes => _state.codes;
  String get code => _state.code;
  String get link => _state.link;

  /// Applies invite fields from a data snapshot and normalizes the links.
  void applySnapshot({
    List<InviteCodeModel>? codes,
    String? code,
    String? link,
    String? urlBase,
  }) {
    _state = _state.copyWith(
      codes: codes,
      code: code,
      link: link,
      urlBase: urlBase,
    );
    final normalized = InviteLinkService.normalize(
      codes: _state.codes,
      inviteCode: _state.code,
      inviteLink: _state.link,
      inviteUrlBase: _state.urlBase,
    );
    _state = _state.copyWith(
      codes: normalized.codes,
      code: normalized.inviteCode,
      link: normalized.inviteLink,
    );
    notifyListeners();
  }

  void reset() {
    _state = const InviteDataState();
    notifyListeners();
  }

  Future<String?> createInviteCode() async {
    try {
      await _api.createInviteCode();
      await _refresh();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('ApiException: ', '');
    }
  }
}
