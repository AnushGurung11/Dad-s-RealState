String formatMoney(double amount) {
  final rounded = amount.toStringAsFixed(2);
  if (rounded.endsWith('.00')) {
    return rounded.substring(0, rounded.length - 3);
  }
  return rounded;
}

String formatMoneyShort(double amount) => 'Rs. ${formatMoney(amount)}';