import 'api_models.dart';

class WalletDataState {
  const WalletDataState({
    this.inviteRecords = const [],
    this.commissionRate = 0,
    this.invitedCount = 0,
    this.earnedCommission = 0,
    this.pendingCommission = 0,
    this.withdrawable = 0,
    this.withdrawClose = 1,
    this.withdrawMethods = const [],
    this.minWithdrawAmount = 0,
    this.currencySymbol = '¥',
  });

  final List<RemoteInviteRecord> inviteRecords;
  final double commissionRate;
  final int invitedCount;
  final double earnedCommission;
  final double pendingCommission;
  final double withdrawable;
  final int withdrawClose;
  final List<String> withdrawMethods;
  final double minWithdrawAmount;
  final String currencySymbol;

  bool get withdrawEnabled => withdrawClose == 0;

  WalletDataState copyWith({
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
    return WalletDataState(
      inviteRecords: inviteRecords ?? this.inviteRecords,
      commissionRate: commissionRate ?? this.commissionRate,
      invitedCount: invitedCount ?? this.invitedCount,
      earnedCommission: earnedCommission ?? this.earnedCommission,
      pendingCommission: pendingCommission ?? this.pendingCommission,
      withdrawable: withdrawable ?? this.withdrawable,
      withdrawClose: withdrawClose ?? this.withdrawClose,
      withdrawMethods: withdrawMethods ?? this.withdrawMethods,
      minWithdrawAmount: minWithdrawAmount ?? this.minWithdrawAmount,
      currencySymbol: currencySymbol ?? this.currencySymbol,
    );
  }
}
