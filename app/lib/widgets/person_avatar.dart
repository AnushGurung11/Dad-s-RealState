import 'dart:io';

import 'package:flutter/material.dart';



/// Tenant avatar: shows the stored photo when [photoPath] is set and the
/// file exists; otherwise falls back to colored initials.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.photoPath,
    required this.name,
    this.radius = 20,
  });

  final String? photoPath;
  final String name;
  final double radius;

  ImageProvider? get _image {
    final path = photoPath;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return FileImage(file);
  }

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  static const _avatarPalette = [
    Color(0xFF4F80E1), // blue
    Color(0xFFE18A4F), // amber
    Color(0xFF34C759), // green
    Color(0xFF7C3AED), // purple
    Color(0xFFFF453A), // red
    Color(0xFF06B6D4), // cyan
  ];

  Color _avatarColor() {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    if (name.isEmpty) return _avatarPalette[0];
    final idx = name.trim().isEmpty ? 0 : name.trim().codeUnitAt(0) % _avatarPalette.length;
    // also mix hash for distribution
    return _avatarPalette[(idx + h) % _avatarPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final accent = _avatarColor();
    return CircleAvatar(
      key: key == null ? const Key('person_avatar') : null,
      radius: radius,
      backgroundImage: image,
      backgroundColor: accent.withValues(alpha: 0.14),
      child: image == null
          ? Text(
              _initials,
              style: TextStyle(
                fontSize: radius * 0.7,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            )
          : null,
    );
  }
}
