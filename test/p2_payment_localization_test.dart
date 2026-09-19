import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';
import 'package:litchi_client/v3/commerce/v3_payment_copy.dart';
import 'package:litchi_client/v3/commerce/v3_payment_flow.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

class _PaymentApi extends PanelApi {
  _PaymentApi() : super(ApiClient());
  int checkoutCalls = 0;

  @override
  Future<List<RemotePaymentMethod>> getPaymentMethods() async =>
      const [RemotePaymentMethod(id: 8, name: '微信支付')];

  @override
  Future<RemoteOrderPaymentDetail> getOrderPaymentDetail(String tradeNo) async =>
      const RemoteOrderPaymentDetail(
        totalAmount: 1280,
        discountAmount: 0,
        surplusAmount: 0,
        balanceAmount: 0,
        refundAmount: 0,
        preHandlingAmount: 0,
        status: 0,
      );

  @override
  Future<CheckoutResult> checkoutOrder(String tradeNo, int? methodId) async {
    checkoutCalls++;
    return const CheckoutResult('', 0);
  }

  @override
  Future<int> checkOrderStatus(String tradeNo) async => 0;
}

void main() {
  test('payment labels follow supported language variants', () {
    final english = V3PaymentCopy.forLocale(const Locale('en'));
    final simplified = V3PaymentCopy.forLocale(const Locale('zh'));
    final traditional = V3PaymentCopy.forLocale(const Locale('zh', 'TW'));
    expect(english.completed, 'Payment complete');
    expect(english.order('123'), 'Order 123');
    expect(simplified.balance, '使用余额完成订单');
    expect(traditional.viewOrders, '查看訂單');
    expect(traditional.pendingPayment, contains('付款'));
  });

  testWidgets('English payment dialog uses localized actions, same server total',
      (tester) async {
    final api = _PaymentApi();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: V3Theme.light(),
      home: Builder(builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => showV3PaymentFlow(
            context: context,
            tradeNo: 'ORDER-123',
            fallbackAmount: 9,
            currencySymbol: '¥',
            api: api,
          ),
          child: const Text('Open'),
        ),
      )),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Complete payment'), findsOneWidget);
    expect(find.text('Order ORDER-123'), findsOneWidget);
    expect(find.text('Amount due'), findsOneWidget);
    expect(find.text('¥12.80'), findsOneWidget);
    expect(find.text('微信支付'), findsOneWidget,
        reason: 'payment method names are supplied by the backend');
    expect(find.text('继续支付'), findsNothing);
    await tester.tap(find.text('Continue to payment'));
    await tester.pumpAndSettle();
    expect(api.checkoutCalls, 1);
    expect(find.textContaining('Payment has not been confirmed'), findsOneWidget);
  });
}
