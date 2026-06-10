import '../../../shared/models/api_models.dart';

int orderDiscountCents({
  required int originalCents,
  required bool couponApplied,
  required CouponResult? coupon,
}) {
  if (!couponApplied || coupon == null) return 0;
  if (coupon.type == 1) return coupon.value;
  if (coupon.type == 2) return (originalCents * coupon.value / 100).round();
  return 0;
}

double orderFinalPrice({
  required int originalCents,
  required int discountCents,
}) {
  return ((originalCents - discountCents) / 100)
      .clamp(0.0, double.infinity);
}
