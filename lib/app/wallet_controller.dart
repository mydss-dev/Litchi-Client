import 'package:flutter/foundation.dart';

import '../shared/models/api_models.dart';
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
    if (_withdrawable <= 0) return '暂无可划转佣金';
    if (amount <= 0) return '请输入划转金额';
    if (amount > _withdrawable) return '划转金额不能超过可提现佣金';
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
    if (amount <= 0) return '请输入提现金额';
    if (!withdrawEnabled) return '提现暂未开放';
    if (amount > _withdrawable) return '提现金额不能超过可提现佣金';
    if (_minWithdrawAmount > 0 && amount < _minWithdrawAmount) {
      return '最低提现金额为 $_currencySymbol${_minWithdrawAmount.toStringAsFixed(2)}';
    }
    if (account.trim().isEmpty) return '请输入提现账户';
    if (method.trim().isEmpty) return '请输入提现方式';
    if (_withdrawMethods.isNotEmpty &&
        !_withdrawMethods.contains(method.trim())) {
      return '请选择可用的提现方式';
    }
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
