import 'package:flutter/material.dart';

import '../config.dart';
import '../models/person.dart';
import '../services/store_scope.dart';
import '../services/tenant_rent_payment_service.dart';
import '../theme/flat_color.dart';
import 'status_badge.dart';

/// Shared tenant picker: flat-grouped, color-coded list with optional search.
/// Used by:
///   - TenantRentPaymentScreen (active-only, `includeArchived: false`,
///     `showPaidBadge: true`)
///   - TenantRentHistoryScreen (active + archived, `includeArchived: true`)
class TenantPickerList extends StatefulWidget {
  const TenantPickerList({
    super.key,
    required this.onPersonTap,
    this.includeArchived = false,
    this.showPaidBadge = false,
    this.emptyText = 'No tenants.',
    this.noMatchesText = 'No tenants match "\$query".',
    this.searchHint = 'Search tenants',
    this.searchKey,
  });

  final ValueChanged<Person> onPersonTap;
  final bool includeArchived;

  /// Renders a "Paid" badge (rent record dated in the current month) or a
  /// muted "Unpaid" label on every active row.
  final bool showPaidBadge;
  final String emptyText;
  final String noMatchesText;
  final String searchHint;
  final Key? searchKey;

  @override
  State<TenantPickerList> createState() => _TenantPickerListState();
}

class _TenantPickerListState extends State<TenantPickerList> {
  String _query = '';
  String? _selectedFlatId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final needle = _query.trim().toLowerCase();

    // Collect all tenants who have been assigned to a bed (current or past).
    // A tenant "belongs" to a flat if they have a flatId set.
    final people = store.people
        .where((p) =>
            p.flatId != null &&
            (widget.includeArchived || p.status == PersonStatus.active) &&
            (_selectedFlatId == null || p.flatId == _selectedFlatId) &&
            (needle.isEmpty || p.name.toLowerCase().contains(needle)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Group by flat.
    final flatIds = people.map((p) => p.flatId!).toSet();
    final flats =
        store.flats.where((f) => flatIds.contains(f.id)).toList();
    flats.sort((a, b) => a.name.compareTo(b.name));

    // All flats for the filter dropdown
    final allFlats = store.flats
        .where((f) => !f.archived)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final children = <Widget>[];

    children.add(
      TextField(
        key: widget.searchKey,
        decoration: InputDecoration(
          hintText: widget.searchHint,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
    );

    if (allFlats.length > 1) {
      children.add(const SizedBox(height: 8));
      children.add(
        DropdownButtonFormField<String>(
          key: const Key('tenant_picker_flat_filter'),
          initialValue: _selectedFlatId,
          decoration: const InputDecoration(
            labelText: 'Filter by flat',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          hint: const Text('All flats'),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('All flats'),
            ),
            ...allFlats.map(
              (f) => DropdownMenuItem(
                value: f.id,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: flatColorFor(f.id),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(f.name),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _selectedFlatId = value),
        ),
      );
    }

    children.add(const SizedBox(height: 12));

    if (people.isEmpty) {
      // Check if there are any people at all (regardless of search)
      final hasAnyPeople = store.people.any((p) =>
          p.flatId != null &&
          (widget.includeArchived || p.status == PersonStatus.active));
      if (hasAnyPeople) {
        // Search has results but filtered out
        children.add(
          Text(
            widget.noMatchesText.replaceAll('\$query', _query),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        );
      } else {
        // No people at all
        children.add(
          Text(
            widget.emptyText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        );
      }
    } else {
      // Separate active and archived people
      final activePeople = people.where((p) => !p.isArchived).toList();
      final archivedPeople = people.where((p) => p.isArchived).toList();

      // Active people grouped by flat
      if (activePeople.isNotEmpty) {
        final activeFlatIds = activePeople.map((p) => p.flatId!).toSet();
        final activeFlats = flats.where((f) => activeFlatIds.contains(f.id)).toList();

        for (final flat in activeFlats) {
          final peopleInFlat = activePeople.where((p) => p.flatId == flat.id).toList();

          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  Container(
                    key: ValueKey('group-dot-${flat.id}'),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: flatColorFor(flat.id),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    flat.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          );

          for (final person in peopleInFlat) {
            children.add(
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(Icons.person_outlined,
                      color: flatColorFor(flat.id)),
                  title: Text(person.name),
                  subtitle: const Text('Active'),
                  trailing: _trailingFor(context, person, false),
                  onTap: () => widget.onPersonTap(person),
                ),
              ),
            );
          }
        }
      }

      // Archived people under separate section
      if (archivedPeople.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Archived',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );

        for (final person in archivedPeople) {
          final flat = flats.where((f) => f.id == person.flatId).firstOrNull;
          children.add(
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(Icons.person_outlined,
                    color: flat != null ? flatColorFor(flat.id).withValues(alpha: 0.4) : null),
                title: Text(person.name),
                subtitle: Text(person.isAbsconded ? 'Absconded' : 'Left'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onPersonTap(person),
              ),
            ),
          );
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  /// Paid/Unpaid badge for payment mode; chevron otherwise.
  Widget? _trailingFor(BuildContext context, Person person, bool archived) {
    if (!widget.showPaidBadge || archived) {
      return const Icon(Icons.chevron_right);
    }
    final month = monthKey(DateTime.now());
    final paid = TenantRentPaymentService.hasPaidForMonth(
        StoreScope.of(context).payments, person.id, month);
    return paid
        ? const StatusBadge(kind: StatusKind.success, label: 'Paid')
        : Text(
            'Unpaid',
            key: Key('unpaid-${person.id}'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          );
  }
}