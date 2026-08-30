import 'package:flutter/material.dart';

import '../models/bed.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/person_avatar.dart';
import 'status_badge.dart';

/// One bed row on a flat's Beds tab. Shows the bed label, the occupant's name
/// (or a "Vacant" badge) and — when occupied — the rent. The left border
/// encodes state: danger when the occupant is overdue, neutral when simply
/// occupied, and vacant beds get a dashed gray outline instead.
/// Also shows the occupant's photo avatar when available.
class BedRow extends StatelessWidget {
  const BedRow({
    super.key,
    required this.bed,
    required this.occupantName,
    this.occupantPhotoPath,
    required this.isOverdue,
    this.onTap,
  });

  final Bed bed;
  final String? occupantName;
  final String? occupantPhotoPath;
  final bool isOverdue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final occupied = bed.isOccupied;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: appSurface1,
          border: Border.all(color: appBorder, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (occupied && occupantName != null) ...[
                  PersonAvatar(
                    photoPath: occupantPhotoPath,
                    name: occupantName!,
                    radius: 18,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bed.label,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: appText1),
                      ),
                      if (occupied && occupantName != null)
                        Text(
                          occupantName!,
                          style: const TextStyle(fontSize: 15, color: appText1),
                        )
                      else
                        const Text('Assign →', style: TextStyle(fontSize: 12, color: appAccent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                if (occupied) ...[
                  Text(
                    formatMoneyShort(bed.defaultMonthlyRent),
                    style: const TextStyle(fontFamily: 'SF Mono', fontFamilyFallback: ['ui-monospace', 'monospace'], fontSize: 12, fontWeight: FontWeight.w600, color: appText1, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  if (isOverdue) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: appDanger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: appDanger.withValues(alpha: 0.18))),
                      child: const Text('Overdue', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: appDanger)),
                    ),
                  ],
                ] else
                  const StatusBadge(kind: StatusKind.neutral, label: 'Vacant'),
              ],
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
