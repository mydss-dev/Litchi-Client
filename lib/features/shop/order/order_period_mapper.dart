import '../../../shared/models/app_models.dart';

const orderPeriodLabels = {
  'month_price': '月付',
  'quarter_price': '季付',
  'half_year_price': '半年付',
  'year_price': '年付',
  'two_year_price': '两年付',
  'three_year_price': '三年付',
  'onetime_price': '一次性',
};

/// Maps [BillingCycle] and one-time plans to the API period key.
String orderPeriodKey(BillingCycle? cycle, PlanModel plan) {
  if (plan.category == PlanCategory.oneTime ||
      plan.category == PlanCategory.dataPack) {
    return 'onetime_price';
  }
  if (cycle != null) {
    final key = switch (cycle) {
      BillingCycle.monthly => 'month_price',
      BillingCycle.quarterly => 'quarter_price',
      BillingCycle.yearly => 'year_price',
    };
    if (plan.priceForCycle(cycle) != null) return key;
  }
  if (plan.monthlyPrice != null) return 'month_price';
  if (plan.quarterlyPrice != null) return 'quarter_price';
  if (plan.yearlyPrice != null) return 'year_price';
  if (plan.oneTimePrice != null) return 'onetime_price';
  return 'month_price';
}
