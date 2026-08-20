import 'package:flutter/material.dart';

/// Temporary body for routes not yet implemented. Chunks 2-8 replace these
/// one at a time with real screen content.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}