import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Caption text for explanatory subtitles in screen bodies.
/// Uses golden-ratio caption scale (9sp), muted color. Not a title.
class ScreenCaption extends StatelessWidget {
  const ScreenCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: AppTextScale.caption,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

/// Legacy ScreenHeader kept for compatibility but now only renders caption.
/// Title rendering removed per patch section 2 — AppBar is the single title.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final caption = subtitle;
    if (caption == null || caption.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ScreenCaption(caption),
    );
  }
}
