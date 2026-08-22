import 'package:flutter/material.dart';

import '../config.dart';
import '../navigation/routes.dart';
import '../widgets/lucky_wordmark.dart';

/// Which part of the settings screen to land on.
enum SettingsSection { archive }

/// Settings: an Archive section with two navigation entries (archived
/// tenants live in one screen, archived flats in another) and an About
/// block with the LUCKY wordmark.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.initialSection});

  final SettingsSection? initialSection;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Archive', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            key: const Key('settings_archived_tenants'),
            leading: const Icon(Icons.person_off_outlined),
            title: const Text('Archived Tenants'),
            subtitle:
                const Text('Tenants whose stay ended or who absconded'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, Routes.archiveTenants),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            key: const Key('settings_archive_flats'),
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('Archived Flats'),
            subtitle:
                const Text('Flats retired from the active grid, kept for records'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, Routes.archiveFlats),
          ),
        ),
        const SizedBox(height: 24),
        Text('About', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        const Center(child: LuckyWordmark()),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'LUCKY ${AppConfig.currencySymbol} tracker for landlords',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
