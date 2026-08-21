import 'package:flutter/material.dart';

import '../models/bed.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'status_badge.dart';

/// One bed row on a flat's Beds tab. Shows the bed label, the occupant's name
/// (or a "Vacant" badge) and — when occupied — the rent. The left border
/// encodes state: danger when the occupant is overdue, neutral when simply
/// occupied, and vacant beds get a dashed gray outline instead.
class BedRow extends StatelessWidget {
  const BedRow({
    super.key,
    required this.bed,
    required this.occupantName,
    required this.isOverdue,
    this.onTap,
  });

  final Bed bed;
  final String? occupantName;
  final bool isOverdue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColors = Theme.of(context).extension<AppStatusColors>()!;
    final occupied = bed.isOccupied;

    final Color accent = switch ((occupied, isOverdue)) {
      (true, true) => statusColors.danger,
      (true, false) => statusColors.neutral,
      (false, _) => statusColors.neutral.withValues(alpha: 0.4),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            foregroundPainter: DashedBorderPainter(
              color: occupied ? Colors.transparent : accent,
              radius: 12,
            ),
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: accent, width: 4)),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bed.label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (occupied && occupantName != null)
                          Text(
                            occupantName!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                  if (occupied)
                    Text(
                      formatMoneyShort(bed.defaultMonthlyRent),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    )
                  else
                    const StatusBadge(kind: StatusKind.neutral, label: 'Vacant'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle outline for vacant bed rows.
class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dashWidth = 6;
  static const double _dashGap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) return;
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect.deflate(1),
          Radius.circular(radius),
        ),
      );
    final dash = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dash.addPath(
          metric.extractPath(distance, distance + _dashWidth),
          Offset.zero,
        );
        distance += _dashWidth + _dashGap;
      }
    }
    canvas.drawPath(
      dash,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
