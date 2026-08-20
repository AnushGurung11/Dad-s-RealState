import 'package:flutter/material.dart';

import '../utils/format.dart';

/// Renders a signed net amount. Always shown as a plain signed number
/// (e.g. `-2,400` or `2,400`), never parentheses. Green for positive,
/// red for negative, neutral for zero.
class NetAmountLabel extends StatelessWidget {
  const NetAmountLabel({super.key, required this.amount, this.style});

  final double amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleMedium;
    final color = amount < 0
        ? Colors.red.shade600
        : amount > 0
            ? Colors.green.shade700
            : Theme.of(context).colorScheme.onSurfaceVariant;
    return Text(
      formatMoneySigned(amount),
      style: base?.copyWith(color: color, fontWeight: FontWeight.bold),
    );
  }
}