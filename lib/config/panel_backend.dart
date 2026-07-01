enum PanelType {
  v2board('v2board'),
  xiaoV2board('xiao_v2board'),
  xboard('xboard');

  const PanelType(this.configValue);

  final String configValue;

  bool get usesFormPost => this != PanelType.v2board;

  static PanelType? tryParse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      'v2board' => PanelType.v2board,
      'xiao_v2board' || 'xiao-v2board' => PanelType.xiaoV2board,
      'xboard' => PanelType.xboard,
      _ => null,
    };
  }
}

class PanelFeatures {
  const PanelFeatures({
    required this.shop,
    required this.invite,
    required this.wallet,
    required this.orders,
    required this.traffic,
    required this.tickets,
    required this.onlineDevices,
  });

  final bool shop;
  final bool invite;
  final bool wallet;
  final bool orders;
  final bool traffic;
  final bool tickets;
  final bool onlineDevices;

  /// Keeps already-published configs behaving exactly as they did before
  /// capability switches were introduced.
  static const legacy = PanelFeatures(
    shop: true,
    invite: true,
    wallet: true,
    orders: true,
    traffic: true,
    tickets: true,
    onlineDevices: true,
  );

  factory PanelFeatures.defaultsFor(PanelType type) => PanelFeatures(
    shop: true,
    invite: true,
    // EZ exposes balance recharge only for Xiao-V2Board.
    wallet: type == PanelType.xiaoV2board,
    orders: true,
    traffic: true,
    tickets: true,
    // EZ only presents the live device-limit feature for Xiao-V2Board.
    onlineDevices: type == PanelType.xiaoV2board,
  );

  PanelFeatures apply(Object? value) {
    if (value is! Map) return this;
    return PanelFeatures(
      shop: _bool(value['shop']) ?? shop,
      invite: _bool(value['invite']) ?? invite,
      wallet: _bool(value['wallet']) ?? wallet,
      orders: _bool(value['orders']) ?? orders,
      traffic: _bool(value['traffic']) ?? traffic,
      tickets: _bool(value['tickets']) ?? tickets,
      onlineDevices: _bool(value['online_devices']) ?? onlineDevices,
    );
  }

  static bool? _bool(Object? value) => value is bool ? value : null;

  String get fingerprint =>
      '$shop,$invite,$wallet,$orders,$traffic,$tickets,$onlineDevices';
}
