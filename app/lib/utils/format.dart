import '../config.dart';

String formatMoney(double amount) {
  final rounded = amount.toStringAsFixed(2);
  if (rounded.endsWith('.00')) {
    return rounded.substring(0, rounded.length - 3);
  }
  return rounded;
}

String formatMoneyShort(double amount) =>
    '${AppConfig.currencySymbol} ${formatMoney(amount)}';

/// Signed money, e.g. `AED -2,400` for negative and `AED 2,400` for positive.
/// Plain sign prefix — never parentheses.
String formatMoneySigned(double amount) {
  final sign = amount < 0 ? '-' : '';
  final digits = formatMoney(amount.abs());
  return '${AppConfig.currencySymbol} $sign$digits';
}