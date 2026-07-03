import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/services/ticket_access.dart';

void main() {
  const baseUser = RemoteUser(
    id: 1,
    email: 'user@example.com',
    balance: 0,
    transferEnable: 0,
    used: 0,
    subscribeStatus: 0,
    planId: 7,
    remindExpire: false,
    remindTraffic: false,
    autoRenewal: false,
  );

  test('recognizes a current plan without blocking plan-free ticket modes', () {
    expect(
      ticketAccountHasActiveSubscription(
        user: baseUser,
        now: DateTime.fromMillisecondsSinceEpoch(1000),
      ),
      isTrue,
    );
    expect(
      ticketAccountHasActiveSubscription(
        user: const RemoteUser(
          id: 2,
          email: 'free@example.com',
          balance: 0,
          transferEnable: 0,
          used: 0,
          subscribeStatus: 0,
          remindExpire: false,
          remindTraffic: false,
          autoRenewal: false,
        ),
      ),
      isFalse,
    );
  });

  test('does not treat an expired plan as active', () {
    const subscribe = RemoteSubscribe(
      subscribeUrl: 'https://example.com/sub',
      planId: 7,
      transferEnable: 100,
      upload: 0,
      download: 0,
      expiredAt: 100,
    );

    expect(
      ticketAccountHasActiveSubscription(
        subscribe: subscribe,
        now: DateTime.fromMillisecondsSinceEpoch(101000),
      ),
      isFalse,
    );
  });

  test('recognizes backend subscription-required errors', () {
    expect(isTicketSubscriptionRequiredError('请先购买套餐'), isTrue);
    expect(
      isTicketSubscriptionRequiredError(
        'You must have a valid subscription to continue',
      ),
      isTrue,
    );
    expect(isTicketSubscriptionRequiredError('存在未关闭的工单'), isFalse);
  });
}
