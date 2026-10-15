import 'package:flutter/foundation.dart';

import '../shared/models/api_models.dart';
import '../shared/services/commission_validation_service.dart';
import '../shared/services/panel_api.dart';

/// Owns the wallet / commission domain: balances, withdraw config, invite
/// records, currency symbol, plus the transfer / withdraw actions. Extracted
/// from [AppController]. Actions re-fetch via the injected [refresh] callback.
class WalletController extends ChangeNotifier {
  WalletController(this._api, this._refresh);

  final PanelApi _api;
  final Future<void> Function() _refresh;

  List<RemoteInviteRecord> _inviteRecords = const [];
  double _commissionRate = 0;
  int _invitedCount = 0;
  double _earnedCommission = 0;
  double _pendingCommission = 0;
  double _withdrawable = 0;
  int _withdrawClose = 1;
  List<String> _withdrawMethods = const [];
  double _minWithdrawAmount = 0;
  String _currencySymbol = '¥';

  /// Set while a transfer / withdraw API call is in flight. Repeat calls
  /// return early instead of double-spending against the stale balance.
  bool _busy = false;

  List<RemoteInviteRecord> get inviteRecords => _inviteRecords;
  double get commissionRate => _commissionRate;
  int get invitedCount => _invitedCount;
  double get earnedCommission => _earnedCommission;
  double get pendingCommission => _pendingCommission;
  double get withdrawable => _withdrawable;
  bool get withdrawEnabled => _withdrawClose == 0;
  List<String> get withdrawMethods => _withdrawMethods;
  double get minWithdrawAmount => _minWithdrawAmount;
  String get currencySymbol => _currencySymbol;
  bool get walletBusy => _busy;

  void applySnapshot({
    List<RemoteInviteRecord>? inviteRecords,
    double? commissionRate,
    int? invitedCount,
    double? earnedCommission,
    double? pendingCommission,
    double? withdrawable,
    int? withdrawClose,
    List<String>? withdrawMethods,
    double? minWithdrawAmount,
    String? currencySymbol,
  }) {
    if (inviteRecords != null) _inviteRecords = inviteRecords;
    if (commissionRate != null) _commissionRate = commissionRate;
    if (invitedCount != null) _invitedCount = invitedCount;
    if (earnedCommission != null) _earnedCommission = earnedCommission;
    if (pendingCommission != null) _pendingCommission = pendingCommission;
    if (withdrawable != null) _withdrawable = withdrawable;
    if (withdrawClose != null) _withdrawClose = withdrawClose;
    if (withdrawMethods != null) _withdrawMethods = withdrawMethods;
    if (minWithdrawAmount != null) _minWithdrawAmount = minWithdrawAmount;
    if (currencySymbol != null && currencySymbol.isNotEmpty) {
      _currencySymbol = currencySymbol;
    }
    notifyListeners();
  }

  void setCurrencySymbol(String symbol) {
    if (symbol.isEmpty || symbol == _currencySymbol) return;
    _currencySymbol = symbol;
    notifyListeners();
  }

  void reset() {
    _inviteRecords = const [];
    _commissionRate = 0;
    _invitedCount = 0;
    _earnedCommission = 0;
    _pendingCommission = 0;
    _withdrawable = 0;
    _withdrawClose = 1;
    _withdrawMethods = const [];
    _minWithdrawAmount = 0;
    _currencySymbol = '¥';
    notifyListeners();
  }

  Future<String?> transferAllCommission() =>
      transferCommissionToBalance(_withdrawable);

  Future<String?> transferCommissionToBalance(double amount) async {
    if (_busy) return '操作仍在处理中，请稍候';
    // One validation voice for every wallet entry point (N08): the UI-side
    // precheck and the controller agree because they share the service.
    final invalid = CommissionValidationService.validateTransfer(
      amount: amount,
      withdrawable: _withdrawable,
    );
    if (invalid != null) return invalid;
    _busy = true;
    notifyListeners();
    try {
      await _api.transferCommission((amount * 100).round());
      await _refresh();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('ApiException: ', '');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<String?> withdrawCommission({
    required double amount,
    required String account,
    required String method,
  }) async {
    if (_busy) return '操作仍在处理中，请稍候';
    // Same shared validation voice as the transfer path (N08).
    final invalid = CommissionValidationService.validateWithdraw(
      amount: amount,
      withdrawable: _withdrawable,
      withdrawEnabled: withdrawEnabled,
      minWithdrawAmount: _minWithdrawAmount,
      currencySymbol: _currencySymbol,
      account: account,
      method: method,
      withdrawMethods: _withdrawMethods,
    );
    if (invalid != null) return invalid;
    _busy = true;
    notifyListeners();
    try {
      await _api.withdrawCommission(
        amountCents: (amount * 100).round(),
        account: account.trim(),
        method: method.trim(),
      );
      await _refresh();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('ApiException: ', '');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
