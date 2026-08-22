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
            (needle.isEmpty || p.name.toLowerCase().contains(needle)))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Group by flat.
    final flatIds = people.map((p) => p.flatId!).toSet();
    final flats =
        store.flats.where((f) => flatIds.contains(f.id)).toList();
    flats.sort((a, b) => a.name.compareTo(b.name));

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
      for (final flat in flats) {
        final peopleInFlat = people.where((p) => p.flatId == flat.id).toList();

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
          final archived = person.isArchived;
          children.add(
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(Icons.person_outlined,
                    color: flatColorFor(flat.id)),
                title: Text(person.name),
                subtitle: Text(archived
                    ? (person.isAbsconded ? 'Absconded' : 'Left')
                    : 'Active'),
                trailing: _trailingFor(context, person, archived),
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