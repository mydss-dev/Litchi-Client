import '../../config/app_config.dart';
import '../models/api_models.dart';
import '../models/app_models.dart';
import '../models/model_mappers.dart';
import 'network_error_classifier.dart';
import 'panel_api.dart';
import 'secure_logger.dart';

/// Mutable bag populated by [DataLoader] with best-effort API results.
/// Null fields indicate the corresponding load was skipped or failed.
class DataSnapshot {
  RemoteUser? remoteUser;
  UserModel? user;
  bool? hasPlan;
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

  /// Non-null when the node subscription fetch failed.
  String? nodesError;
}

/// Fetches all remote data and returns a [DataSnapshot].
///
/// All individual loads are best-effort — failures are swallowed and the
/// corresponding field is left null. [AppController] applies non-null fields.
class DataLoader {
  const DataLoader(this._api);

  final PanelApi _api;

  /// Full load: user-info first (sequential), then all others in parallel.
  Future<DataSnapshot> loadAll() async {
    final snap = await loadAccountStatus();
    await loadSupplementary(snap);
    return snap;
  }

  /// Loads data that is not required to paint the account summary.
  ///
  /// Keeping this separate lets the controller render user, quota and expiry
  /// as soon as they arrive instead of waiting for every dashboard endpoint.
  Future<DataSnapshot> loadSupplementary(DataSnapshot snap) async {
    await Future.wait([loadPrimary(snap), loadSecondary(snap)]);
    return snap;
  }

  /// Loads the remaining fields visible on the first dashboard frame.
  Future<void> loadPrimary(DataSnapshot snap) async {
    await Future.wait([
      _fillNodes(snap),
      if (AppConfig.panelFeatures.shop) _fillPlans(snap),
    ]);
  }

  /// Loads non-critical detail pages without delaying first-frame content.
  Future<void> loadSecondary(DataSnapshot snap) async {
    await Future.wait([
      if (AppConfig.panelFeatures.invite) _fillInvite(snap),
      if (AppConfig.panelFeatures.traffic) _fillTrafficLog(snap),
    ]);
  }

  /// Partial load: only re-fetch nodes for [subscribeUrl].
  Future<DataSnapshot> loadNodes(String subscribeUrl) async {
    final snap = DataSnapshot()..subscribeUrl = subscribeUrl;
    await _fillNodes(snap);
    return snap;
  }

  /// Lightweight refresh: only the live account counters the user watches
  /// (remaining traffic, expiry, device count). Does NOT touch nodes, plans,
  /// invite data, or the core — safe to call on a timer while connected.
  Future<DataSnapshot> loadAccountStatus({bool silent = false}) async {
    final snap = DataSnapshot();
    await _fillUserInfo(snap, silent: silent);
    return snap;
  }

  // ── Private fill methods ─────────────────────────────────────────────────

  Future<void> _fillUserInfo(DataSnapshot snap, {bool silent = false}) async {
    final sw = Stopwatch()..start();
    var userLoaded = false;
    var subscribeLoaded = false;
    var subscribeHasPlanEvidence = false;

    Future<void> loadUser() async {
      try {
        final info = await _api.getUserInfo(silent: silent);
        userLoaded = true;
        snap.remoteUser = info;
        snap.user = ModelMappers.toUser(info);
        snap.currentPlanId = info.planId;
        snap.traffic = ModelMappers.toTraffic(info);
      } catch (e) {
        SecureLogger.warn(
          'DataLoader getUserInfo failed after ${sw.elapsedMilliseconds}ms',
          e,
        );
        snap.criticalError = '用户信息加载失败，请检查网络后重试';
      }
    }

    Future<void> loadSubscribe() async {
      try {
        final subscribe = await _api.getSubscribeInfo(silent: silent);
        subscribeLoaded = true;
        snap.subscribeUrl = subscribe.subscribeUrl;
        if (subscribe.subscribeUrl.trim().isEmpty) {
          SecureLogger.warn(
            'DataLoader getSubscribeInfo: subscribe_url empty '
            '(planId=${subscribe.planId}, transferEnable=${subscribe.transferEnable})',
          );
        }
        snap.currentPlanId ??= subscribe.planId;
        subscribeHasPlanEvidence =
            (subscribe.planId != null && subscribe.planId! > 0) ||
            subscribe.subscribeUrl.trim().isNotEmpty ||
            subscribe.transferEnable > 0;
        if (AppConfig.panelFeatures.onlineDevices) {
          snap.aliveIp = subscribe.aliveIp;
          snap.deviceLimit = subscribe.deviceLimit;
        }
        snap.resetDay = subscribe.resetDay;
        snap.expiredAt = subscribe.expiredAt;
        if (subscribe.transferEnable > 0) {
          final total = subscribe.transferEnable / AppConfig.bytesPerGb;
          final used =
              (subscribe.upload + subscribe.download) / AppConfig.bytesPerGb;
          final remain = (total - used).clamp(0.0, double.infinity);
          snap.traffic = TrafficModel(
            totalGb: total,
            usedGb: used,
            remainGb: remain,
          );
        }
      } catch (e) {
        SecureLogger.warn(
          'DataLoader getSubscribeInfo failed after ${sw.elapsedMilliseconds}ms',
          e,
        );
      }
    }

    await Future.wait([loadUser(), loadSubscribe()]);

    if (userLoaded || subscribeLoaded) {
      snap.hasPlan =
          (snap.currentPlanId != null && snap.currentPlanId! > 0) ||
          (snap.remoteUser?.hasPlanEvidence ?? false) ||
          subscribeHasPlanEvidence;
      if (snap.hasPlan == false) {
        // An explicit no-plan response must clear any cached subscription
        // values instead of leaving the previous plan visible indefinitely.
        snap.currentPlanId = null;
        snap.subscribeUrl = '';
        snap.traffic = const TrafficModel(totalGb: 0, usedGb: 0, remainGb: 0);
        snap.aliveIp = null;
        snap.deviceLimit = null;
        snap.resetDay = null;
        snap.expiredAt = null;
      }
    }
  }

  Future<void> _fillNodes(DataSnapshot snap) async {
    final sw = Stopwatch()..start();
    final url = snap.subscribeUrl;
    if (url == null || url.isEmpty) {
      SecureLogger.warn(
        'DataLoader _fillNodes: subscribe_url empty, skipping node fetch',
      );
      return;
    }
    try {
      final result = await _api.fetchSubscription(url);
      if (result.nodes.isNotEmpty) {
        snap.nodes = result.nodes.map(ModelMappers.toNode).toList();
      }
      final st = result.traffic;
      if (st != null && st.total > 0) {
        final total = st.total / AppConfig.bytesPerGb;
        final used = (st.upload + st.download) / AppConfig.bytesPerGb;
        final remain = (total - used).clamp(0.0, double.infinity);
        snap.traffic = TrafficModel(
          totalGb: total,
          usedGb: used,
          remainGb: remain,
        );
      }
    } catch (e) {
      SecureLogger.warn(
        'DataLoader fetchSubscription failed after ${sw.elapsedMilliseconds}ms',
        e,
      );
      snap.nodesError = NetworkErrorClassifier.isNetworkError(e)
          ? '节点加载失败，请检查网络后重试'
          : '节点数据解析失败，请刷新后重试';
    }
  }

  Future<void> _fillPlans(DataSnapshot snap) async {
    final sw = Stopwatch()..start();
    try {
      final plans = await _api.getPlans();
      if (plans.isNotEmpty) {
        final mapped = plans.map(ModelMappers.toPlan).toList();
        snap.plans = mapped;
        final currentPlan = _planById(mapped, snap.currentPlanId);
        final user = snap.user;
        if (user != null && user.plan.trim().isEmpty && currentPlan != null) {
          snap.user = user.copyWith(plan: currentPlan.title);
        }
      }
    } catch (e) {
      SecureLogger.warn(
        'DataLoader getPlans failed after ${sw.elapsedMilliseconds}ms',
        e,
      );
    }
  }

  PlanModel? _planById(List<PlanModel> plans, int? id) {
    if (id == null || id <= 0) return null;
    for (final plan in plans) {
      if (int.tryParse(plan.id) == id) return plan;
    }
    return null;
  }

  Future<void> _fillInvite(DataSnapshot snap) async {
    final sw = Stopwatch()..start();
    try {
      final info = await _api.getInviteInfo();
      if (info.codes.isNotEmpty) {
        snap.inviteCodes = info.codes
            .map((item) => InviteCodeModel(code: item.code, link: item.link))
            .toList();
      }
      if (info.inviteCode.isNotEmpty) snap.inviteCode = info.inviteCode;
      if (info.inviteUrl.isNotEmpty) snap.inviteLink = info.inviteUrl;
      snap.commissionRate = info.commissionRate;
      snap.invitedCount = info.effectCount;
      snap.earnedCommission = info.validCommission / 100;
      snap.pendingCommission = info.pendingCommission / 100;
      snap.withdrawable = info.balance / 100; // balance stored in cents
      final commConfig = await _api.getCommConfig();
      if (commConfig.inviteUrlBase.isNotEmpty) {
        snap.inviteUrlBase = commConfig.inviteUrlBase;
      }
      snap.currencySymbol = commConfig.currencySymbol;
      snap.withdrawClose = commConfig.withdrawClose;
      snap.withdrawMethods = commConfig.withdrawMethods;
      snap.minWithdrawAmount = commConfig.minWithdrawAmount / 100;
      snap.inviteRecords = await _api.getInviteDetails(pageSize: 10);
    } catch (e) {
      SecureLogger.warn(
        'DataLoader getInvite failed after ${sw.elapsedMilliseconds}ms',
        e,
      );
    }
  }

  Future<void> _fillTrafficLog(DataSnapshot snap) async {
    final sw = Stopwatch()..start();
    try {
      final logs = await _api.getTrafficLog();
      if (logs.isNotEmpty) {
        final totalDaily = <DateTime, double>{};
        final uploadDaily = <DateTime, double>{};
        final downloadDaily = <DateTime, double>{};
        for (final log in logs) {
          final date = DateTime(log.date.year, log.date.month, log.date.day);
          totalDaily[date] =
              (totalDaily[date] ?? 0) + log.traffic / AppConfig.bytesPerGb;
          uploadDaily[date] =
              (uploadDaily[date] ?? 0) + log.upload / AppConfig.bytesPerGb;
          downloadDaily[date] =
              (downloadDaily[date] ?? 0) + log.download / AppConfig.bytesPerGb;
        }
        final points =
            totalDaily.entries
                .map(
                  (e) => TrafficUsagePoint(
                    date: e.key,
                    totalGb: e.value,
                    uploadGb: uploadDaily[e.key] ?? 0,
                    downloadGb: downloadDaily[e.key] ?? 0,
                  ),
                )
                .toList()
              ..sort((a, b) => a.date.compareTo(b.date));
        snap.trafficUsage = points;
        snap.dailyUsage = points.map((p) => p.totalGb).toList();
      }
    } catch (e) {
      SecureLogger.warn(
        'DataLoader getTrafficLog failed after ${sw.elapsedMilliseconds}ms',
        e,
      );
    }
  }
}
