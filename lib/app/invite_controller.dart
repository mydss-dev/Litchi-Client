import 'package:flutter/foundation.dart';

import '../shared/config/app_config.dart';
import '../shared/models/app_models.dart';
import '../shared/services/panel_api.dart';

/// Owns the invite domain: invite codes, share link, fallback URL base, and
/// code creation. Link normalization lives here so it is the single authority
/// for invite link shape. Extracted from [AppController].
class InviteController extends ChangeNotifier {
  InviteController(this._api, this._refresh);

  final PanelApi _api;
  final Future<void> Function() _refresh;

  List<InviteCodeModel> _codes = const [];
  String _code = '';
  String _link = '';
  String _urlBase = '';

  List<InviteCodeModel> get inviteCodes => _codes;
  String get inviteCode => _code;
  String get inviteLink => _link;

  /// Applies invite fields from a snapshot, then normalizes every link.
  void applySnapshot({
    List<InviteCodeModel>? codes,
    String? code,
    String? link,
    String? urlBase,
  }) {
    if (urlBase != null) _urlBase = urlBase;
    if (code != null) _code = code;
    if (link != null) _link = link;
    if (codes != null) _codes = codes;

    if (_code.isNotEmpty) {
      _link = _linkForCode(_code, _link);
    }
    if (_codes.isEmpty && _code.isNotEmpty) {
      _codes = [
        InviteCodeModel(code: _code, link: _linkForCode(_code, _link)),
      ];
    } else if (_codes.isNotEmpty) {
      _codes = _codes
          .map(
            (item) => InviteCodeModel(
              code: item.code,
              link: _linkForCode(item.code, item.link),
            ),
          )
          .toList();
      _code = _codes.first.code;
      _link = _codes.first.link;
    }
    notifyListeners();
  }

  void reset() {
    _codes = const [];
    _code = '';
    _link = '';
    _urlBase = '';
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

  String _linkForCode(String code, String link) {
    if (link.isNotEmpty) return link;
    if (code.isEmpty) return '';
    final configuredBase = _firstNotEmpty([_urlBase, AppConfig.inviteUrlBase]);
    if (configuredBase.isEmpty) return '';
    final base = configuredBase.replaceAll(RegExp(r'/+$'), '');
    if (base.contains('{code}')) return base.replaceAll('{code}', code);
    if (base.endsWith('/register') || base.endsWith('/#/register')) {
      return '$base?code=$code';
    }
    return '$base/#/register?code=$code';
  }

  String _firstNotEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }
}
