import 'package:flutter/material.dart';

import '../models/bed.dart';
import '../models/person.dart';
import '../services/store_scope.dart';
import '../theme/flat_color.dart';
import '../utils/format.dart';

/// Flat-grouped, color-coded list of assigned tenants. Shared by the Assign
/// page ("Currently assigned") and the Tenant Rent Payment page so both stay
/// visually identical: one header row per flat (dot tinted via [flatColorFor])
/// followed by its tenants.
class GroupedTenantList extends StatelessWidget {
  const GroupedTenantList({
    super.key,
    required this.beds,
    required this.onPersonTap,
  });

  /// Occupied beds to render, grouped by their flat.
  final List<Bed> beds;

  /// Invoked when a tenant row is tapped.
  final ValueChanged<Person> onPersonTap;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final widgets = <Widget>[];

    final flatIds = beds.map((b) => b.flatId).toSet();
    final flats =
        store.flats.where((f) => flatIds.contains(f.id)).toList();

    for (final flat in flats) {
      final bedsInFlat =
          beds.where((b) => b.flatId == flat.id).toList()
            ..sort((a, b) => a.label.compareTo(b.label));

      widgets.add(Padding(
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
      ));

      for (final bed in bedsInFlat) {
        final tenant = store.people
            .where((p) => p.id == bed.tenantId)
            .firstOrNull;
        widgets.add(Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading:
                Icon(Icons.person_outlined, color: flatColorFor(flat.id)),
            title: Text(tenant?.name ?? 'Unknown'),
            subtitle: Text(
                '${bed.label} · ${formatMoneyShort(bed.defaultMonthlyRent)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap:
                tenant == null ? null : () => onPersonTap(tenant),
          ),
        ));
      }
    }

    return Column(children: widgets);
  }
}
