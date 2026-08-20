String formatMoney(double amount) {
  final rounded = amount.toStringAsFixed(2);
  if (rounded.endsWith('.00')) {
    return rounded.substring(0, rounded.length - 3);
  }
  return rounded;
}

String formatMoneyShort(double amount) => 'Rs. ${formatMoney(amount)}';

/// Signed money, e.g. `Rs. -2,400` for negative and `Rs. 2,400` for positive.
/// Plain sign prefix — never parentheses.
String formatMoneySigned(double amount) {
  final sign = amount < 0 ? '-' : '';
  final digits = formatMoney(amount.abs());
  return 'Rs. $sign$digits';
}