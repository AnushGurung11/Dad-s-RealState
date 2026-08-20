import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The set of visual states every "Paid"/"Overdue"/"Vacant"-style badge can be
/// in. Colors come from [AppStatusColors], never hardcoded hex values.
enum StatusKind { success, warning, danger, neutral }

/// Reusable pill badge for status labels. Future screens must use this widget
/// for status indicators instead of one-off colored containers.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.kind, required this.label});

  final StatusKind kind;
  final String label;

  Color _color(BuildContext context) {
    final colors = Theme.of(context).extension<AppStatusColors>()!;
    return switch (kind) {
      StatusKind.success => colors.success,
      StatusKind.warning => colors.warning,
      StatusKind.danger => colors.danger,
      StatusKind.neutral => colors.neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}