import 'package:flutter/material.dart';

import '../models/person.dart';
import '../navigation/routes.dart';
import '../services/store_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';

/// Archive of former tenants: both naturally-ended stays (`archived` —
/// neutral gray "Left" badge) and flagged departures (`absconded` — red
/// "Absconded" badge with the status note visible). Tapping opens the
/// read-only person detail.
class ArchiveTenantsScreen extends StatefulWidget {
  const ArchiveTenantsScreen({super.key});

  @override
  State<ArchiveTenantsScreen> createState() => _ArchiveTenantsScreenState();
}

class _ArchiveTenantsScreenState extends State<ArchiveTenantsScreen> {
  String _query = '';

  String? _dateText(DateTime? date) => date == null
      ? null
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final archived = store.people
        .where((p) => p.status != PersonStatus.active)
        .toList()
      ..sort((a, b) => (b.statusDate ?? DateTime(0))
          .compareTo(a.statusDate ?? DateTime(0)));

    final needle = _query.trim().toLowerCase();
    final filtered = needle.isEmpty
        ? archived
        : archived
            .where((p) => p.name.toLowerCase().contains(needle))
            .toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
          key: const Key('archive_search_field'),
          decoration: const InputDecoration(
            hintText: 'Search archived tenants',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 8),
        if (archived.isEmpty)
          Text(
            'No archived tenants.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else if (filtered.isEmpty)
          Text(
            'No matches for "$_query".',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else
          ...filtered.map(_archiveTile),
        ],
      ),
    );
  }

  Widget _archiveTile(Person person) {
    final store = StoreScope.of(context);
    final flat =
        store.flats.where((f) => f.id == person.flatId).firstOrNull;
    final bed = store.beds.where((b) => b.id == person.bedId).firstOrNull;
    final former = [flat?.name, bed?.label].whereType<String>().join(' · ');
    final absconded = person.isAbsconded;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        key: ValueKey('archive-person-${person.id}'),
        leading: Icon(
          absconded ? Icons.warning_amber_outlined : Icons.person_off_outlined,
          color: absconded ? Theme.of(context).extension<AppStatusColors>()!.danger : null,
        ),
        title: Row(
          children: [
            Expanded(child: Text(person.name)),
            StatusBadge(
              kind: absconded ? StatusKind.danger : StatusKind.neutral,
              label: absconded ? 'Absconded' : 'Left',
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (former.isNotEmpty) Text(former),
            Text(
              '${absconded ? 'Flagged' : 'Left'} '
              '${_dateText(person.statusDate) ?? '—'} · '
              'Vacated ${_dateText(person.vacatedDate) ?? '—'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            // The "why" behind an absconding is part of the permanent record.
            if (absconded && (person.statusNote?.isNotEmpty ?? false))
              Text(
                person.statusNote!,
                key: ValueKey('status-note-${person.id}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .extension<AppStatusColors>()!
                          .danger,
                      fontStyle: FontStyle.italic,
                    ),
              ),
          ],
        ),
        isThreeLine: true,
        onTap: () => Navigator.pushNamed(
          context,
          Routes.tenantsDetail,
          arguments: person.id,
        ),
      ),
    );
  }
}
