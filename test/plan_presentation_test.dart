import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/plan_presentation.dart';

final _now = DateTime(2026, 9, 17, 12);

PlanPresentation _plan({
  bool hasPlan = true,
  String name = 'Litchi Ultra',
  int? status,
  int? expiredAt,
  String expiry = '2026-12-31',
  double quota = 512,
  double remaining = 200,
}) => PlanPresentation.resolve(
  hasPlan: hasPlan,
  name: name,
  subscribeStatus: status,
  expiredAt: expiredAt,
  expiryLabel: expiry,
  quotaGb: quota,
  remainingGb: remaining,
  now: _now,
);

void main() {
  test('no subscription never shows a phantom plan or expiry', () {
    final plan = _plan(hasPlan: false, name: 'stale name');
    expect(plan.name, '暂无套餐');
    expect(plan.statusKind, PlanStatus.notSubscribed);
    expect(plan.expiryKind, PlanExpiryKind.none);
    expect(plan.expiryDate, isNull);
    expect(plan.usable, false);
  });

  test('missing name is not represented as an activated product', () {
    final plan = _plan(name: '套餐名称待同步', expiry: '未提供');
    expect(plan.statusKind, PlanStatus.pendingSync);
    expect(plan.expiryKind, PlanExpiryKind.pendingSync);
    expect(plan.usable, false);
  });

  test('future expiry with a real name is in use', () {
    final plan = _plan();
    expect(plan.statusKind, PlanStatus.normal);
    expect(plan.expiryKind, PlanExpiryKind.date);
    // A date-only value expires *after* its calendar day: the instant is the
    // following midnight, not the printed date itself.
    expect(plan.expiryDate, DateTime(2027, 1, 1));
    expect(plan.usable, true);
  });

  test('explicit subscription expired state overrides future date', () {
    final plan = _plan(status: 1);
    expect(plan.statusKind, PlanStatus.expired);
    expect(plan.usable, false);
  });

  test('banned subscription never paints a verified active icon', () {
    final plan = _plan(status: 2);
    expect(plan.statusKind, PlanStatus.banned);
    expect(plan.usable, false);
  });

  test('expired timestamp takes precedence over a stale expiry label', () {
    final plan = _plan(
      expiredAt: DateTime(2026, 9, 1).millisecondsSinceEpoch ~/ 1000,
    );
    expect(plan.statusKind, PlanStatus.expired);
    // A Unix timestamp is the exact expiry instant, unlike a date-only value.
    expect(plan.expiryKind, PlanExpiryKind.date);
    expect(plan.expiryDate, DateTime(2026, 9, 1));
    expect(plan.usable, false);
  });

  test('a date-only expiry remains valid through its calendar day', () {
    final plan = _plan(expiry: '2026-09-17');
    expect(plan.statusKind, PlanStatus.normal);
    expect(plan.usable, true);
    expect(_plan(expiry: '2026-09-16').statusKind, PlanStatus.expired);
  });

  test('depleted quota is explicit, not accidentally marked active', () {
    final plan = _plan(remaining: 0);
    expect(plan.statusKind, PlanStatus.quotaExhausted);
    expect(plan.usable, false);
  });

  test('permanent is only displayed when API explicitly says so', () {
    final plan = _plan(expiry: '永久');
    expect(plan.statusKind, PlanStatus.normal);
    expect(plan.expiryKind, PlanExpiryKind.permanent);
    expect(_plan(expiry: '未提供').expiryKind, PlanExpiryKind.pendingSync);
  });

  test('URL-only evidence does not assert an active subscription', () {
    final plan = _plan(expiry: '未提供', quota: 0, remaining: 0);
    expect(plan.statusKind, PlanStatus.pendingSync);
    expect(plan.usable, false);
  });
}
