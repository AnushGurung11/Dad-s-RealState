import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/flat_color.dart';

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

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return CircleAvatar(
      key: key == null ? const Key('person_avatar') : null,
      radius: radius,
      backgroundImage: image,
      backgroundColor:
          flatColorFor(name).withValues(alpha: 0.25),
      child: image == null
          ? Text(
              _initials,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: flatColorFor(name),
                  ),
            )
          : null,
    );
  }
}
