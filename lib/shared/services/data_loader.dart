import '../models/api_models.dart';
import '../models/app_models.dart';
import 'invite_data_service.dart';
import 'panel_api.dart';
import 'plan_data_service.dart';
import 'secure_logger.dart';
import 'subscription_data_service.dart';
import 'traffic_data_service.dart';
import 'user_data_service.dart';

/// Mutable bag populated by [DataLoader] with best-effort API results.
/// Null fields indicate the corresponding load was skipped or failed.
class DataSnapshot {
  UserModel? user;
  int? currentPlanId;
  TrafficModel? traffic;
  String? subscribeUrl;
  List<NodeModel>? nodes;
  List<PlanModel>? plans;
  List<InviteCodeModel>? inviteCodes;
  String? inviteCode;
  String? inviteLink;
  String? inviteUrlBase;
  List<RemoteInviteRecord>? inviteRecords;
  double? commissionRate;
  int? invitedCount;
  double? earnedCommission;
  double? pendingCommission;
  double? withdrawable;
  String? currencySymbol;
  int? withdrawClose;
  List<String>? withdrawMethods;
  double? minWithdrawAmount;
  List<double>? dailyUsage;
  List<TrafficUsagePoint>? trafficUsage;
  int? aliveIp;
  int? deviceLimit;
  int? resetDay;
  int? expiredAt;

  /// Non-null when a critical load (user info) failed.
  String? criticalError;
}

/// Fetches all remote data and returns a [DataSnapshot].
///
/// All individual loads are best-effort — failures are swallowed and the
/// corresponding field is left null. [AppController] applies non-null fields.
class DataLoader {
  DataLoader(PanelApi api)
    : _inviteData = InviteDataService(api),
      _planData = PlanDataService(api),
      _subscriptionData = SubscriptionDataService(api),
      _trafficData = TrafficDataService(api),
      _userData = UserDataService(api);
  final InviteDataService _inviteData;
  final PlanDataService _planData;
  final SubscriptionDataService _subscriptionData;
  final TrafficDataService _trafficData;
  final UserDataService _userData;

  /// Full load: user-info first (sequential), then all others in parallel.
  Future<DataSnapshot> loadAll() async {
    final snap = DataSnapshot();
    await _fillUserInfo(snap);
    await Future.wait([
      _fillNodes(snap),
      _fillPlans(snap),
      _fillInvite(snap),
      _fillTrafficLog(snap),
    ]);
    return snap;
  }

  /// Partial load: only re-fetch nodes for [subscribeUrl].
  Future<DataSnapshot> loadNodes(String subscribeUrl) async {
    final snap = DataSnapshot()..subscribeUrl = subscribeUrl;
    await _fillNodes(snap);
    return snap;
  }

  // ── Private fill methods ─────────────────────────────────────────────────

  Future<void> _fillUserInfo(DataSnapshot snap) async {
    try {
      final result = await _userData.loadUser();
      snap.user = result.user;
      snap.currentPlanId = result.currentPlanId;
      snap.traffic = result.traffic;
    } catch (e) {
      SecureLogger.debug('[Litchi] getUserInfo error', e);
      snap.criticalError = '用户信息加载失败，请检查网络后重试';
    }
    try {
      final result = await _userData.loadSubscribe();
      snap.subscribeUrl = result.subscribeUrl;
      snap.aliveIp = result.aliveIp;
      snap.deviceLimit = result.deviceLimit;
      snap.resetDay = result.resetDay;
      snap.expiredAt = result.expiredAt;
      if (result.traffic != null) {
        snap.traffic = result.traffic;
      }
    } catch (e) {
      SecureLogger.debug('[Litchi] getSubscribeInfo error', e);
    }
  }

  Future<void> _fillNodes(DataSnapshot snap) async {
    final url = snap.subscribeUrl;
    if (url == null || url.isEmpty) {
      SecureLogger.debug('[Litchi] _fillNodes: no subscribe URL, skipping');
      return;
    }
    try {
      final result = await _subscriptionData.loadNodes(url);
      if (result.nodes.isNotEmpty) {
        snap.nodes = result.nodes;
      }
      if (result.traffic != null) {
        snap.traffic = result.traffic;
      }
    } catch (e) {
      SecureLogger.debug('[Litchi] _fillNodes error', e);
    }
  }

  Future<void> _fillPlans(DataSnapshot snap) async {
    try {
      final result = await _planData.loadPlans(
        currentPlanId: snap.currentPlanId,
        currentUser: snap.user,
      );
      if (result.plans.isNotEmpty) {
        snap.plans = result.plans;
      }
      if (result.user != null) {
        snap.user = result.user;
      }
    } catch (e) {
      SecureLogger.debug('[Litchi] getPlans error', e);
    }
  }

  Future<void> _fillInvite(DataSnapshot snap) async {
    try {
      final result = await _inviteData.loadInvite();
      if (result.inviteCodes != null) {
        snap.inviteCodes = result.inviteCodes;
      }
      if (result.inviteCode != null) {
        snap.inviteCode = result.inviteCode;
      }
      if (result.inviteLink != null) {
        snap.inviteLink = result.inviteLink;
      }
      if (result.inviteUrlBase != null) {
        snap.inviteUrlBase = result.inviteUrlBase;
      }
      if (result.commissionRate != null) {
        snap.commissionRate = result.commissionRate;
      }
      if (result.invitedCount != null) {
        snap.invitedCount = result.invitedCount;
      }
      if (result.earnedCommission != null) {
        snap.earnedCommission = result.earnedCommission;
      }
      if (result.pendingCommission != null) {
        snap.pendingCommission = result.pendingCommission;
      }
      if (result.withdrawable != null) {
        snap.withdrawable = result.withdrawable;
      }
      if (result.currencySymbol != null) {
        snap.currencySymbol = result.currencySymbol;
      }
      if (result.withdrawClose != null) {
        snap.withdrawClose = result.withdrawClose;
      }
      if (result.withdrawMethods != null) {
        snap.withdrawMethods = result.withdrawMethods;
      }
      if (result.minWithdrawAmount != null) {
        snap.minWithdrawAmount = result.minWithdrawAmount;
      }
      if (result.inviteRecords != null) {
        snap.inviteRecords = result.inviteRecords;
      }
    } catch (e) {
      SecureLogger.debug('[Litchi] getInviteInfo error', e);
    }
  }

  Future<void> _fillTrafficLog(DataSnapshot snap) async {
    try {
      final result = await _trafficData.loadTrafficLog();
      if (result.trafficUsage.isNotEmpty) {
        snap.trafficUsage = result.trafficUsage;
      }
      if (result.dailyUsage.isNotEmpty) {
        snap.dailyUsage = result.dailyUsage;
      }
    } catch (e) {
      SecureLogger.debug('[Litchi] getTrafficLog error', e);
    }
  }
}
