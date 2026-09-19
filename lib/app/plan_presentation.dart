// One truthful plan presentation for the dashboard, shop, account and rail.
// A subscription URL is plan evidence, not proof that it is active.
import 'app_controller.dart';

class PlanPresentation {
  const PlanPresentation({
    required this.name,
    required this.status,
    required this.expiry,
    required this.usable,
  });

  final String name;
  final String status;
  final String expiry;
  final bool usable;

  String get shortLabel => name == '暂无套餐' ? name : '$name · $status';

  /// An explicit date takes precedence over a conflicting permanent sentinel;
  /// a cached '永久' label with no timestamp evidence is unverified.
  static String expiryLabelWithEvidence({
    required String label,
    required int? accountExpiry,
    required int? subscriptionExpiry,
  }) {
    if ((accountExpiry != null && accountExpiry > 0) ||
        (subscriptionExpiry != null && subscriptionExpiry > 0)) {
      return label.trim() == '永久' ? '未提供' : label;
    }
    if (accountExpiry == 0 || subscriptionExpiry == 0) return '永久';
    return label.trim() == '永久' ? '未提供' : label;
  }

  static int? expiryTimestampWithEvidence({
    required int? accountExpiry,
    required int? subscriptionExpiry,
  }) {
    if (subscriptionExpiry != null && subscriptionExpiry > 0) {
      return subscriptionExpiry;
    }
    if (accountExpiry != null && accountExpiry > 0) return accountExpiry;
    return subscriptionExpiry ?? accountExpiry;
  }

  factory PlanPresentation.fromController(
    AppController controller, {
    DateTime? now,
  }) {
    final userName = controller.user.plan.trim();
    final remoteName = controller.accountDetails?.planName.trim() ?? '';
    final planId = controller.currentPlanId;
    final catalogName = planId == null
        ? ''
        : controller.plans
            .where((plan) => plan.id == planId.toString())
            .map((plan) => plan.title.trim())
            .where((title) => title.isNotEmpty)
            .firstOrNull ?? '';
    // RemoteUser.planLabel can be a synthetic "已到期" instead of a name.
    final realUserName = userName == '已到期' && remoteName.isEmpty
        ? ''
        : userName;
    final name = realUserName.isNotEmpty
        ? realUserName
        : remoteName.isNotEmpty
            ? remoteName
            : catalogName.isNotEmpty
                ? catalogName
                : '套餐名称待同步';
    final accountExpiry = controller.accountDetails?.expiredAt;
    final subscriptionExpiry = controller.expiredAt;
    return PlanPresentation.resolve(
      hasPlan: controller.hasPlan,
      name: name,
      subscribeStatus: controller.accountDetails?.subscribeStatus,
      expiredAt: expiryTimestampWithEvidence(
        accountExpiry: accountExpiry,
        subscriptionExpiry: subscriptionExpiry,
      ),
      expiryLabel: expiryLabelWithEvidence(
        label: controller.planExpiryLabel,
        accountExpiry: accountExpiry,
        subscriptionExpiry: subscriptionExpiry,
      ),
      quotaGb: controller.traffic.totalGb,
      remainingGb: controller.traffic.remainGb,
      now: now,
    );
  }

  factory PlanPresentation.resolve({
    required bool hasPlan,
    required String name,
    required int? subscribeStatus,
    required int? expiredAt,
    required String expiryLabel,
    required double quotaGb,
    required double remainingGb,
    DateTime? now,
  }) {
    if (!hasPlan) {
      return const PlanPresentation(
        name: '暂无套餐',
        status: '未开通',
        expiry: '尚未开通套餐',
        usable: false,
      );
    }

    final effectiveNow = now ?? DateTime.now();
    final rawExpiry = expiryLabel.trim();
    final timestampDate = expiredAt != null && expiredAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000)
        : null;
    final dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawExpiry);
    final parsed = dateOnly ? DateTime.tryParse(rawExpiry) : null;
    // A date-only panel value expires *after* its calendar date, while a Unix
    // timestamp gives the exact expiry instant.
    final expiryInstant = timestampDate ??
        (parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day + 1));
    final timestampLabel = timestampDate == null
        ? null
        : '${timestampDate.year}-${timestampDate.month.toString().padLeft(2, '0')}-${timestampDate.day.toString().padLeft(2, '0')}';
    final expiry = timestampLabel != null
        ? '到期 $timestampLabel'
        : rawExpiry == '永久'
            ? '永久有效'
            : dateOnly && parsed != null
                ? '到期 $rawExpiry'
                : '有效期待同步';

    if (subscribeStatus == 2) {
      return PlanPresentation(name: name, status: '已停用', expiry: expiry, usable: false);
    }
    if (subscribeStatus == 1 ||
        (expiryInstant != null && !effectiveNow.isBefore(expiryInstant))) {
      return PlanPresentation(name: name, status: '已到期', expiry: expiry, usable: false);
    }
    if (quotaGb > 0 && remainingGb <= 0) {
      return PlanPresentation(name: name, status: '流量已用尽', expiry: expiry, usable: false);
    }
    final validityKnown = expiryInstant != null || rawExpiry == '永久';
    return PlanPresentation(
      name: name,
      status: validityKnown ? '使用中' : '状态待同步',
      expiry: expiry,
      usable: validityKnown,
    );
  }
}
