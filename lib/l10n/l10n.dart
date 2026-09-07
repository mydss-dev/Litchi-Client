import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'app_locale_preference.dart';
export 'generated/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Small desktop-only labels introduced between localization generation cycles.
/// Keeping them here preserves English / Simplified Chinese / Traditional
/// Chinese behavior without hard-coding one language inside widgets.
extension DesktopUiLocalizations on AppLocalizations {
  bool get _isTraditionalChinese {
    final locale = localeName.toLowerCase().replaceAll('-', '_');
    return locale.startsWith('zh_tw') ||
        locale.startsWith('zh_hk') ||
        locale.startsWith('zh_hant');
  }

  bool get _isChinese => localeName.toLowerCase().startsWith('zh');

  String get realtimeStatusLabel {
    if (_isTraditionalChinese) return '即時狀態';
    if (_isChinese) return '实时状态';
    return 'Live status';
  }

  String get viewUsageLabel {
    if (_isTraditionalChinese) return '查看用量';
    if (_isChinese) return '查看用量';
    return 'View usage';
  }

  String get connectionDurationLabel {
    if (_isTraditionalChinese) return '連線時長';
    if (_isChinese) return '连接时长';
    return 'Connection time';
  }

  String get todayUsedLabel {
    if (_isTraditionalChinese) return '今日已用';
    if (_isChinese) return '今日已用';
    return 'Used today';
  }

  String get periodUsedLabel {
    if (_isTraditionalChinese) return '本週期已用';
    if (_isChinese) return '本周期已用';
    return 'Used this cycle';
  }

  String get remainingTrafficLabel {
    if (_isTraditionalChinese) return '剩餘流量';
    if (_isChinese) return '剩余流量';
    return 'Remaining traffic';
  }

  String get remainingDaysLabel {
    if (_isTraditionalChinese) return '剩餘天數';
    if (_isChinese) return '剩余天数';
    return 'Days remaining';
  }

  String get resetCountdownLabel {
    if (_isTraditionalChinese) return '距流量重置';
    if (_isChinese) return '距流量重置';
    return 'Traffic reset in';
  }

  String comparedYesterdayLabel(String value) {
    if (_isTraditionalChinese) return '較昨日 $value';
    if (_isChinese) return '较昨日 $value';
    return '$value vs yesterday';
  }

  String yesterdayUsageLabel(String value) {
    if (_isTraditionalChinese) return '昨日 $value';
    if (_isChinese) return '昨日 $value';
    return 'Yesterday $value';
  }

  String totalTrafficLabel(String value) {
    if (_isTraditionalChinese) return '總計 $value';
    if (_isChinese) return '总计 $value';
    return 'Total $value';
  }
}
