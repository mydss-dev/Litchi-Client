import 'package:flutter/foundation.dart';

import '../shared/models/api_models.dart';
import '../shared/models/wallet_data_state.dart';
import '../shared/services/commission_validation_service.dart';
import '../shared/services/panel_api.dart';

/// Owns the wallet / commission domain: balances, withdraw config, and the
/// transfer / withdraw actions. Extracted from [AppController] so wallet state
/// is an independently testable, independently observable unit.
///
/// Action methods re-fetch via the injected [refresh] callback (the app-level
/// reload) so the rest of the snapshot stays consistent.
class WalletController extends ChangeNotifier {
  WalletController(this._api, this._refresh);

  final PanelApi _api;
  final Future<void> Function() _refresh;

  WalletDataState _state = const WalletDataState();
  WalletDataState get state => _state;

  // ── Getters (mirror the previous AppController surface) ────────────────────

  List<RemoteInviteRecord> get inviteRecords => _state.inviteRecords;
  double get commissionRate => _state.commissionRate;
  int get invitedCount => _state.invitedCount;
  double get earnedCommission => _state.earnedCommission;
  double get pendingCommission => _state.pendingCommission;
  double get withdrawable => _state.withdrawable;
  bool get withdrawEnabled => _state.withdrawEnabled;
  List<String> get withdrawMethods => _state.withdrawMethods;
  double get minWithdrawAmount => _state.minWithdrawAmount;
  String get currencySymbol => _state.currencySymbol;

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Applies wallet fields from a freshly loaded data snapshot.
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
    _state = _state.copyWith(
      inviteRecords: inviteRecords,
      commissionRate: commissionRate,
      invitedCount: invitedCount,
      earnedCommission: earnedCommission,
      pendingCommission: pendingCommission,
      withdrawable: withdrawable,
      withdrawClose: withdrawClose,
      withdrawMethods: withdrawMethods,
      minWithdrawAmount: minWithdrawAmount,
      currencySymbol: (currencySymbol?.isNotEmpty ?? false)
          ? currencySymbol
          : null,
    );
    notifyListeners();
  }

  void setCurrencySymbol(String symbol) {
    if (symbol.isEmpty || symbol == _state.currencySymbol) return;
    _state = _state.copyWith(currencySymbol: symbol);
    notifyListeners();
  }

  void reset() {
    _state = const WalletDataState();
    notifyListeners();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<String?> transferAllCommission() =>
      transferCommissionToBalance(_state.withdrawable);

  Future<String?> transferCommissionToBalance(double amount) async {
    final validationError = CommissionValidationService.validateTransfer(
      amount: amount,
      withdrawable: _state.withdrawable,
    );
    if (validationError != null) return validationError;
    try {
      await _api.transferCommission((amount * 100).round());
      await _refresh();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('ApiException: ', '');
    }
  }

  Future<String?> withdrawCommission({
    required double amount,
    required String account,
    required String method,
  }) async {
    final validationError = CommissionValidationService.validateWithdraw(
      amount: amount,
      withdrawable: _state.withdrawable,
      withdrawEnabled: _state.withdrawEnabled,
      minWithdrawAmount: _state.minWithdrawAmount,
      currencySymbol: _state.currencySymbol,
      account: account,
      method: method,
      withdrawMethods: _state.withdrawMethods,
    );
    if (validationError != null) return validationError;
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
    }
  }
}
