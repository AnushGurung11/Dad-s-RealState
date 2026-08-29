import 'package:flutter/material.dart';

import '../models/flat.dart';
import '../services/store_scope.dart';
import '../utils/format.dart';
import '../widgets/status_badge.dart';

/// Standalone archive for soft-deleted flats. Read-only: view each flat's
/// Lease info and historical bed/tenant data; no re-activation action.
class ArchiveFlatsScreen extends StatelessWidget {
  const ArchiveFlatsScreen({super.key});

  String _dateText(DateTime? date) => date == null
      ? '—'
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final archived = store.flats.where((f) => f.archived).toList()
      ..sort((a, b) => (b.archivedAt ?? DateTime(0))
          .compareTo(a.archivedAt ?? DateTime(0)));

    if (archived.isEmpty) {
      return Center(
        child: Text(
          'No archived flats.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final flat in archived)
          Card(
            key: ValueKey('archived-flat-${flat.id}'),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.apartment_outlined),
              title: Text(flat.name),
              subtitle: Text(
                '${flat.address}\n'
                'Archived ${_dateText(flat.archivedAt)}',
              ),
              isThreeLine: true,
              trailing:
                  const StatusBadge(kind: StatusKind.neutral, label: 'Archived'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      _ArchivedFlatDetailScreen(flat: flat),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Read-only historical view of one archived flat: lease fields plus every
/// bed and its (possibly former) occupants. Nothing here is editable.
class _ArchivedFlatDetailScreen extends StatelessWidget {
  const _ArchivedFlatDetailScreen({required this.flat});

  final Flat flat;

  String _dateText(DateTime? date) => date == null
      ? '—'
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final beds = store.beds
        .where((b) => b.flatId == flat.id)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return Scaffold(
      appBar: AppBar(title: Text(flat.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const StatusBadge(kind: StatusKind.neutral, label: 'Archived'),
                const SizedBox(width: 8),
                Text(
                  'Archived ${_dateText(flat.archivedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Lease info', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _Field(label: 'Address', value: flat.address),
            _Field(
              label: 'Flat registered on',
              value: _dateText(flat.registeredDate),
            ),
            _Field(label: 'Contract person', value: flat.contractPerson),
            _Field(
              label: 'Yearly rent',
              value: flat.yearlyRent == null
                  ? null
                  : formatMoneyShort(flat.yearlyRent!),
            ),
            const SizedBox(height: 12),
            Text('Utilities & Contacts',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: 8),
            _Field(label: 'Landline number', value: flat.landlineNumber),
            _Field(
                label: 'Landline registered name',
                value: flat.landlineRegisteredName),
            _Field(label: 'Esewa number', value: flat.esewaNumber),
            _Field(label: 'Wifi name', value: flat.wifiName),
            _Field(label: 'Wifi password', value: flat.wifiPassword),
            const Divider(height: 32),
            Text('Beds & tenant history',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...beds.map((bed) {
              final occupant = bed.tenantId == null
                  ? null
                  : store.people
                      .where((p) => p.id == bed.tenantId)
                      .firstOrNull;
              return Card(
                key: ValueKey('archive-bed-${bed.id}'),
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(
                    Icons.bed_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(bed.label),
                  subtitle: Text(
                    occupant?.name ?? 'No tenant assigned',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Text(
                    formatMoneyShort(bed.defaultMonthlyRent),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            (value == null || value!.isEmpty) ? '—' : value!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
