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

/// Compact money for tight spaces: `12.4K AED`, `-1.25M AED`, `950 AED`.
/// Keeps large figures readable inside fixed-width cards so they never clip.
String formatMoneyCompact(double amount) {
  final sign = amount < 0 ? '-' : '';
  final abs = amount.abs();
  String digits;
  if (abs >= 1000000) {
    digits = _trimZero(abs / 1000000, suffix: 'M');
  } else if (abs >= 10000) {
    digits = _trimZero(abs / 1000, suffix: 'K');
  } else {
    digits = formatMoney(abs);
  }
  return '$sign$digits ${AppConfig.currencySymbol}';
}

String _trimZero(double value, {required String suffix}) {
  var text = value < 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(0);
  if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
  return '$text$suffix';
}