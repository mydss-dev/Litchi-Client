import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';

/// One set of payment labels for every money-taking entry point. Backend
/// payment method names and error messages remain server-provided content.
class V3PaymentCopy {
  const V3PaymentCopy._(this._language);

  final String _language;

  factory V3PaymentCopy.forLocale(Locale locale) {
    if (locale.languageCode != 'zh') {
      return const V3PaymentCopy._('en');
    }
    final traditional = locale.countryCode == 'TW' ||
        locale.countryCode == 'HK' ||
        locale.countryCode == 'MO' ||
        locale.scriptCode == 'Hant';
    return V3PaymentCopy._(traditional ? 'tw' : 'zh');
  }

  static V3PaymentCopy of(BuildContext context) {
    // Existing standalone payment widget tests intentionally omit the app's
    // localization delegates. Match the rest of V3's Chinese fallback there.
    if (Localizations.of<AppLocalizations>(context, AppLocalizations) == null) {
      return const V3PaymentCopy._('zh');
    }
    return V3PaymentCopy.forLocale(Localizations.localeOf(context));
  }

  String _tr(String zh, String en, String tw) => switch (_language) {
    'en' => en,
    'tw' => tw,
    _ => zh,
  };

  String get pendingPayment => _tr(
    '暂未检测到支付完成，可以稍后再次检查。',
    'Payment has not been confirmed yet. Please check again later.',
    '尚未偵測到付款完成，請稍後再次檢查。',
  );
  String get completed => _tr('支付完成', 'Payment complete', '付款完成');
  String get syncing => _tr(
    '账户数据正在同步到 Litchi。',
    'Your account data is syncing to Litchi.',
    '帳戶資料正在同步至 Litchi。',
  );
  String get done => _tr('完成', 'Done', '完成');
  String get viewOrders => _tr('查看订单', 'View orders', '查看訂單');
  String get kicker => _tr('支付中心', 'PAYMENT', '付款中心');
  String get title => _tr('完成支付', 'Complete payment', '完成付款');
  String get close => _tr('关闭', 'Close', '關閉');
  String order(String number) => _tr('订单 $number', 'Order $number', '訂單 $number');
  String get amountDue => _tr('需支付', 'Amount due', '應付金額');
  String get paymentMethod => _tr('支付方式', 'Payment method', '付款方式');
  String get noMethods => _tr(
    '当前没有可用支付方式',
    'No payment methods are currently available',
    '目前沒有可用的付款方式',
  );
  String get browserOpened => _tr(
    '支付页面已尝试在浏览器打开',
    'The payment page was opened in your browser',
    '已嘗試在瀏覽器開啟付款頁面',
  );
  String get scanQr => _tr(
    '请使用对应支付应用扫码',
    'Scan with the corresponding payment app',
    '請使用對應付款應用程式掃碼',
  );
  String get reopen => _tr('重新打开支付页面', 'Reopen payment page', '重新開啟付款頁面');
  String get starting => _tr('正在发起支付…', 'Starting payment…', '正在發起付款…');
  String get balance => _tr('使用余额完成订单', 'Pay with balance', '使用餘額完成訂單');
  String get continuePayment => _tr('继续支付', 'Continue to payment', '繼續付款');
  String get checking => _tr('正在检查…', 'Checking…', '正在檢查…');
  String get paid => _tr('我已完成支付', 'I have paid', '我已完成付款');
}
