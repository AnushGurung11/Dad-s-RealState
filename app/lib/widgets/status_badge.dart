import 'package:flutter/material.dart';

import '../models/payment.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final PaymentStatus status;

  Color _color(BuildContext context) {
    switch (status) {
      case PaymentStatus.paid:
        return Colors.green.shade600;
      case PaymentStatus.partial:
        return Colors.amber.shade700;
      case PaymentStatus.unpaid:
        return Colors.red.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}