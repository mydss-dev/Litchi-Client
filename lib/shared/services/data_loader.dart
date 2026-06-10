import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';
import '../models/model_mappers.dart';
import 'panel_api.dart';

/// Mutable bag populated by [DataLoader] with best-effort API results.
/// Null fields indicate the corresponding load was skipped or failed.
class DataSnapshot {
  UserModel? user;
  TrafficModel? traffic;
  String? subscribeUrl;
  List<NodeModel>? nodes;
  List<PlanModel>? plans;
  String? inviteCode;
  String? inviteLink;
  double? commissionRate;
  int? invitedCount;
  double? withdrawable;
  List<double>? dailyUsage;
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
      final info = await _api.getUserInfo();
      snap.user    = ModelMappers.toUser(info);
      snap.traffic = ModelMappers.toTraffic(info);
    } catch (_) {}
    try {
      snap.subscribeUrl = await _api.getSubscribeUrl();
    } catch (e) {
      debugPrint('[Litchi] getSubscribeUrl error: $e');
    }
  }

  Future<void> _fillNodes(DataSnapshot snap) async {
    final url = snap.subscribeUrl;
    if (url == null || url.isEmpty) {
      debugPrint('[Litchi] _fillNodes: no subscribe URL, skipping');
      return;
    }
    try {
      final result = await _api.fetchSubscription(url);
      if (result.nodes.isNotEmpty) {
        snap.nodes = result.nodes.map(ModelMappers.toNode).toList();
      }
      final st = result.traffic;
      if (st != null && st.total > 0) {
        final total  = st.total / AppConfig.bytesPerGb;
        final used   = (st.upload + st.download) / AppConfig.bytesPerGb;
        final remain = (total - used).clamp(0.0, double.infinity);
        snap.traffic = TrafficModel(totalGb: total, usedGb: used, remainGb: remain);
      }
    } catch (e) {
      debugPrint('[Litchi] _fillNodes error: $e');
    }
  }

  Future<void> _fillPlans(DataSnapshot snap) async {
    try {
      final plans = await _api.getPlans();
      if (plans.isNotEmpty) {
        snap.plans = plans.map(ModelMappers.toPlan).toList();
      }
    } catch (_) {}
  }

  Future<void> _fillInvite(DataSnapshot snap) async {
    try {
      final info = await _api.getInviteInfo();
      if (info.inviteCode.isNotEmpty) snap.inviteCode = info.inviteCode;
      if (info.inviteUrl.isNotEmpty)  snap.inviteLink = info.inviteUrl;
      snap.commissionRate = info.commissionRate;
      snap.invitedCount   = info.effectCount;
      snap.withdrawable   = info.balance / 100; // balance stored in cents
    } catch (_) {}
  }

  Future<void> _fillTrafficLog(DataSnapshot snap) async {
    try {
      final logs = await _api.getTrafficLog();
      if (logs.isNotEmpty) {
        snap.dailyUsage =
            logs.map((l) => l.traffic / AppConfig.bytesPerGb).toList();
      }
    } catch (_) {}
  }
}
