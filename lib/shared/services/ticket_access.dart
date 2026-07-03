import '../models/api_models.dart';

bool ticketAccountHasActiveSubscription({
  RemoteUser? user,
  RemoteSubscribe? subscribe,
  DateTime? now,
}) {
  final planId = user?.planId ?? subscribe?.planId;
  final hasPlanMarker =
      (planId != null && planId > 0) ||
      (user?.planName.trim().isNotEmpty ?? false) ||
      (subscribe?.transferEnable ?? 0) > 0;
  if (!hasPlanMarker) return false;

  final expiredAt = subscribe?.expiredAt ?? user?.expiredAt;
  if (expiredAt == null || expiredAt == 0) return true;
  final currentSeconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  return expiredAt > currentSeconds;
}

bool isTicketSubscriptionRequiredError(Object error) {
  final message = error
      .toString()
      .replaceFirst('ApiException: ', '')
      .trim()
      .toLowerCase();
  return message.contains('请先购买套餐') ||
      message.contains('请先购买订阅') ||
      message.contains('purchase a plan') ||
      message.contains('valid subscription');
}

Future<T?> ticketBestEffort<T>(Future<T> request) async {
  try {
    return await request;
  } catch (_) {
    return null;
  }
}
