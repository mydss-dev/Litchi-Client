import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/subscription_controller.dart';

void main() {
  test('applySnapshot stores fields and preserves omitted ones', () {
    final c = SubscriptionController();
    c.applySnapshot(
      subscribeUrl: 'https://sub.example/abc',
      deviceLimit: 3,
      expiredAt: 1893456000,
    );
    expect(c.subscribeUrl, 'https://sub.example/abc');
    expect(c.deviceLimit, 3);
    expect(c.expiredAt, 1893456000);

    // Omitted fields keep their previous values.
    c.applySnapshot(dailyUsage: const [1, 2, 3]);
    expect(c.subscribeUrl, 'https://sub.example/abc');
    expect(c.dailyUsage, const [1, 2, 3]);
  });

  test('reset clears subscription state', () {
    final c = SubscriptionController();
    c.applySnapshot(subscribeUrl: 'https://sub.example/abc', deviceLimit: 5);
    c.reset();
    expect(c.subscribeUrl, isEmpty);
    expect(c.deviceLimit, isNull);
  });
}
