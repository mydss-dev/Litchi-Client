abstract final class CommissionValidationService {
  static String? validateTransfer({
    required double amount,
    required double withdrawable,
  }) {
    if (withdrawable <= 0) return '暂无可划转佣金';
    if (amount <= 0) return '请输入划转金额';
    if (amount > withdrawable) return '划转金额不能超过可提现佣金';
    return null;
  }

  static String? validateWithdraw({
    required double amount,
    required double withdrawable,
    required bool withdrawEnabled,
    required double minWithdrawAmount,
    required String currencySymbol,
    required String account,
    required String method,
    required List<String> withdrawMethods,
  }) {
    final trimmedAccount = account.trim();
    final trimmedMethod = method.trim();

    if (amount <= 0) return '请输入提现金额';
    if (!withdrawEnabled) return '提现暂未开放';
    if (amount > withdrawable) return '提现金额不能超过可提现佣金';
    if (minWithdrawAmount > 0 && amount < minWithdrawAmount) {
      return '最低提现金额为 $currencySymbol${minWithdrawAmount.toStringAsFixed(2)}';
    }
    if (trimmedAccount.isEmpty) return '请输入提现账户';
    if (trimmedMethod.isEmpty) return '请输入提现方式';
    if (withdrawMethods.isNotEmpty &&
        !withdrawMethods.contains(trimmedMethod)) {
      return '请选择可用的提现方式';
    }
    return null;
  }
}
