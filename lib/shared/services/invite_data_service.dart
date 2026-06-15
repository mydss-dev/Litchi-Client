import '../models/api_models.dart';
import '../models/app_models.dart';
import 'panel_api.dart';

class InviteDataResult {
  const InviteDataResult({
    this.inviteCodes,
    this.inviteCode,
    this.inviteLink,
    this.inviteUrlBase,
    this.inviteRecords,
    this.commissionRate,
    this.invitedCount,
    this.earnedCommission,
    this.pendingCommission,
    this.withdrawable,
    this.currencySymbol,
    this.withdrawClose,
    this.withdrawMethods,
    this.minWithdrawAmount,
  });

  final List<InviteCodeModel>? inviteCodes;
  final String? inviteCode;
  final String? inviteLink;
  final String? inviteUrlBase;
  final List<RemoteInviteRecord>? inviteRecords;
  final double? commissionRate;
  final int? invitedCount;
  final double? earnedCommission;
  final double? pendingCommission;
  final double? withdrawable;
  final String? currencySymbol;
  final int? withdrawClose;
  final List<String>? withdrawMethods;
  final double? minWithdrawAmount;
}

class InviteDataService {
  const InviteDataService(this._api);

  final PanelApi _api;

  Future<InviteDataResult> loadInvite() async {
    final info = await _api.getInviteInfo();
    final commConfig = await _api.getCommConfig();
    final records = await _api.getInviteDetails(pageSize: 10);

    return InviteDataResult(
      inviteCodes: info.codes.isEmpty
          ? null
          : info.codes
                .map(
                  (item) => InviteCodeModel(code: item.code, link: item.link),
                )
                .toList(),
      inviteCode: info.inviteCode.isEmpty ? null : info.inviteCode,
      inviteLink: info.inviteUrl.isEmpty ? null : info.inviteUrl,
      commissionRate: info.commissionRate,
      invitedCount: info.effectCount,
      earnedCommission: info.validCommission / 100,
      pendingCommission: info.pendingCommission / 100,
      withdrawable: info.balance / 100,
      inviteUrlBase: commConfig.inviteUrlBase.isEmpty
          ? null
          : commConfig.inviteUrlBase,
      currencySymbol: commConfig.currencySymbol,
      withdrawClose: commConfig.withdrawClose,
      withdrawMethods: commConfig.withdrawMethods,
      minWithdrawAmount: commConfig.minWithdrawAmount / 100,
      inviteRecords: records,
    );
  }
}
