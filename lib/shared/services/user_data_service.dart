import '../config/app_config.dart';
import '../models/app_models.dart';
import '../models/model_mappers.dart';
import 'panel_api.dart';

class UserDataResult {
  const UserDataResult({
    this.user,
    this.currentPlanId,
    this.traffic,
    this.subscribeUrl,
    this.aliveIp,
    this.deviceLimit,
    this.resetDay,
    this.expiredAt,
  });

  final UserModel? user;
  final int? currentPlanId;
  final TrafficModel? traffic;
  final String? subscribeUrl;
  final int? aliveIp;
  final int? deviceLimit;
  final int? resetDay;
  final int? expiredAt;
}

class UserDataService {
  const UserDataService(this._api);

  final PanelApi _api;

  Future<UserDataResult> loadUser() async {
    final info = await _api.getUserInfo();
    return UserDataResult(
      user: ModelMappers.toUser(info),
      currentPlanId: info.planId,
      traffic: ModelMappers.toTraffic(info),
    );
  }

  Future<UserDataResult> loadSubscribe() async {
    final subscribe = await _api.getSubscribeInfo();
    return UserDataResult(
      subscribeUrl: subscribe.subscribeUrl,
      aliveIp: subscribe.aliveIp,
      deviceLimit: subscribe.deviceLimit,
      resetDay: subscribe.resetDay,
      expiredAt: subscribe.expiredAt,
      traffic: subscribe.transferEnable > 0
          ? trafficFromSubscribe(
              transferEnable: subscribe.transferEnable,
              upload: subscribe.upload,
              download: subscribe.download,
            )
          : null,
    );
  }

  static TrafficModel trafficFromSubscribe({
    required double transferEnable,
    required double upload,
    required double download,
  }) {
    final total = transferEnable / AppConfig.bytesPerGb;
    final used = (upload + download) / AppConfig.bytesPerGb;
    final remain = (total - used).clamp(0.0, double.infinity);
    return TrafficModel(totalGb: total, usedGb: used, remainGb: remain);
  }
}
