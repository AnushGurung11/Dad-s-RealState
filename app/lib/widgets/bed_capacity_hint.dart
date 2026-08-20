import 'package:flutter/material.dart';

import '../services/bed_capacity_service.dart';

/// Shows the current bed count against the 5-20 capacity rule, e.g. "7 / 20
/// beds", so the constraint is never a surprise.
class BedCapacityHint extends StatelessWidget {
  const BedCapacityHint({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final atLimit = count >= BedCapacityService.maxBeds;
    final color = atLimit ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        '$count / ${BedCapacityService.maxBeds} beds',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}