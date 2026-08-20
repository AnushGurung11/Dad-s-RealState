import 'package:flutter/material.dart';

/// Fixed rotating palette of 8 distinguishable, accessible hues. The palette
/// deliberately avoids the status colors (green/amber/red/gray) so "this flat
/// is orange" is never confused with "this is overdue".
const List<Color> flatPalette = [
  Color(0xFF4F46E5), // indigo
  Color(0xFF0D9488), // teal
  Color(0xFFEA580C), // orange
  Color(0xFFDB2777), // pink
  Color(0xFF0891B2), // cyan
  Color(0xFF7C3AED), // violet
  Color(0xFF65A30D), // lime
  Color(0xFF92400E), // brown
];

/// Deterministic per-flat color: the same [flatId] always maps to the same
/// palette entry (stable across restarts and rebuilds).
Color flatColorFor(String flatId) {
  var hash = 0;
  for (final unit in flatId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7FFFFFFF;
  }
  return flatPalette[hash % flatPalette.length];
}