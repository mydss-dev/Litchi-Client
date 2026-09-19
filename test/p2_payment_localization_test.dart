import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';
import 'package:litchi_client/v3/commerce/v3_payment_flow.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

class _PaymentApi extends PanelApi {
  _PaymentApi() : super(ApiClient());

  @override
  Future<List<RemotePaymentMethod>> getPaymentMethods() async => const [
    RemotePaymentMethod(id: 7, name: 'Card'),
  ];

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
}

void main() {
  testWidgets('payment dialog uses English copy in English locale', (tester) async {
    final api = _PaymentApi();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: V3Theme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showV3PaymentFlow(
                context: context,
                tradeNo: 'L-P2-EN',
                fallbackAmount: 12.8,
                currencySymbol: r'$',
                api: api,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Complete payment'), findsOneWidget);
    expect(find.text('Amount due'), findsOneWidget);
    expect(find.text('Payment method'), findsOneWidget);
    expect(find.text('Continue to pay'), findsOneWidget);
    expect(find.text('完成支付'), findsNothing);
    expect(find.text('需支付'), findsNothing);
  });
}
