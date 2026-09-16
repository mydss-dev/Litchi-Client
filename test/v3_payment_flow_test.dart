import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';
import 'package:litchi_client/v3/commerce/v3_payment_flow.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

/// Drives the shared payment dialog against a scripted backend. Every method the
/// flow reaches for is overridden — an unoverridden one would hit the network.
class _FakePaymentApi extends PanelApi {
  _FakePaymentApi({
    this.methods = const [RemotePaymentMethod(id: 7, name: '微信支付')],
    required this.detail,
    this.checkout = const CheckoutResult('', 0),
    this.status = 0,
    this.loadError,
  }) : super(ApiClient());

  final List<RemotePaymentMethod> methods;
  final RemoteOrderPaymentDetail detail;
  final CheckoutResult checkout;
  final int status;

  /// Thrown from both load calls when set, to exercise the failure path.
  final Object? loadError;

  int checkoutCalls = 0;
  int? lastMethodId;

  @override
  Future<List<RemotePaymentMethod>> getPaymentMethods() async {
    if (loadError != null) throw loadError!;
    return methods;
  }

  @override
  Future<RemoteOrderPaymentDetail> getOrderPaymentDetail(String tradeNo) async {
    if (loadError != null) throw loadError!;
    return detail;
  }

  @override
  Future<CheckoutResult> checkoutOrder(String tradeNo, int? methodId) async {
    checkoutCalls++;
    lastMethodId = methodId;
    return checkout;
  }

  @override
  Future<int> checkOrderStatus(String tradeNo) async => status;
}

RemoteOrderPaymentDetail _detail({
  int? totalAmount = 1280,
  int balanceAmount = 0,
  int status = 0,
}) => RemoteOrderPaymentDetail(
  totalAmount: totalAmount,
  discountAmount: 0,
  surplusAmount: 0,
  balanceAmount: balanceAmount,
  refundAmount: 0,
  preHandlingAmount: 0,
  status: status,
);

Future<void> _pumpFlow(
  WidgetTester tester,
  _FakePaymentApi api, {
  double fallbackAmount = 0,
  VoidCallback? onViewOrders,
  Future<void> Function()? onPaid,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: V3Theme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showV3PaymentFlow(
                context: context,
                tradeNo: 'L202609160001',
                fallbackAmount: fallbackAmount,
                currencySymbol: '¥',
                api: api,
                onPaid: onPaid,
                onViewOrders: onViewOrders,
              ),
              child: const Text('pay'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('pay'));
  await tester.pumpAndSettle();
}

void main() {
  // The amount the previous screen quoted is an estimate built from local plan
  // prices. The backend total is the one that actually gets charged, so the
  // dialog has to prefer it rather than reassure the user with its own guess.
  testWidgets('shows the backend total instead of the caller estimate', (
    tester,
  ) async {
    final api = _FakePaymentApi(detail: _detail(totalAmount: 1280));
    await _pumpFlow(tester, api, fallbackAmount: 9.99);

    expect(find.text('¥12.80'), findsOneWidget);
    expect(find.text('¥9.99'), findsNothing);
  });

  testWidgets('falls back to the estimate until the backend answers', (
    tester,
  ) async {
    // A detail with no total_amount leaves the fallback as the only figure.
    final api = _FakePaymentApi(detail: _detail(totalAmount: null));
    await _pumpFlow(tester, api, fallbackAmount: 9.99);

    expect(find.text('¥9.99'), findsOneWidget);
  });

  testWidgets('settles a balance-only order without picking a method', (
    tester,
  ) async {
    final api = _FakePaymentApi(
      detail: _detail(totalAmount: 0, balanceAmount: 1200),
      status: 3,
    );
    await _pumpFlow(tester, api, fallbackAmount: 12);

    // Nothing left to pay externally, so offering payment methods would only
    // invite the user to pick one that cannot apply.
    expect(find.text('微信支付'), findsNothing);
    expect(find.text('使用余额完成订单'), findsOneWidget);

    await tester.tap(find.text('使用余额完成订单'));
    await tester.pumpAndSettle();

    expect(api.checkoutCalls, 1);
    expect(find.text('支付完成'), findsOneWidget);
  });

  testWidgets('an order the backend already settled opens on the paid view', (
    tester,
  ) async {
    final api = _FakePaymentApi(detail: _detail(status: 3));
    var paid = 0;
    await _pumpFlow(tester, api, onPaid: () async => paid++);

    expect(find.text('支付完成'), findsOneWidget);
    expect(find.text('需支付'), findsNothing);
    expect(paid, 1, reason: 'the caller must be told to refresh');
  });

  testWidgets('sends the chosen method to checkout and shows the QR', (
    tester,
  ) async {
    final api = _FakePaymentApi(
      methods: const [
        RemotePaymentMethod(id: 7, name: '微信支付'),
        RemotePaymentMethod(id: 9, name: '支付宝'),
      ],
      detail: _detail(),
      checkout: const CheckoutResult('weixin://pay/abc', 0),
    );
    await _pumpFlow(tester, api, fallbackAmount: 12.8);

    await tester.tap(find.widgetWithText(ChoiceChip, '支付宝'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续支付'));
    await tester.pumpAndSettle();

    expect(
      api.lastMethodId,
      9,
      reason: 'the picked method must be the one sent',
    );
    expect(find.text('请使用对应支付应用扫码'), findsOneWidget);
  });

  // The shop's deleted copy showed '$error' verbatim, which for anything that
  // is not an ApiException leaks the wrapper class into the user's face.
  testWidgets('unwraps non-API errors instead of showing the wrapper type', (
    tester,
  ) async {
    final api = _FakePaymentApi(
      detail: _detail(),
      loadError: Exception('连接超时'),
    );
    await _pumpFlow(tester, api);

    expect(find.text('连接超时'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('offers a route to the order only when the caller has one', (
    tester,
  ) async {
    final api = _FakePaymentApi(detail: _detail(status: 3));
    var viewed = 0;
    await _pumpFlow(tester, api, onViewOrders: () => viewed++);

    expect(find.text('查看订单'), findsOneWidget);
    await tester.tap(find.text('查看订单'));
    await tester.pumpAndSettle();

    expect(viewed, 1);
    expect(
      find.text('支付完成'),
      findsNothing,
      reason: 'the dialog must close before the caller navigates',
    );
  });

  testWidgets('hides the order route for a caller that is already on orders', (
    tester,
  ) async {
    final api = _FakePaymentApi(detail: _detail(status: 3));
    await _pumpFlow(tester, api);

    expect(find.text('查看订单'), findsNothing);
  });
}
