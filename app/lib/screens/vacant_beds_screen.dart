import 'package:flutter/material.dart';

import '../models/bed.dart';
import '../models/flat.dart';
import '../navigation/routes.dart';
import '../services/store_scope.dart';
import '../theme/flat_color.dart';
import '../utils/format.dart';

/// Vacant Beds screen: flat-grouped list of only vacant beds; tapping a bed
/// opens Assign directly for it.
class VacantBedsScreen extends StatelessWidget {
  const VacantBedsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final flats = store.flats.where((f) => !f.archived).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final vacantByFlat = <String, List<Bed>>{};
    for (final bed in store.beds.where((b) => b.tenantId == null)) {
      final flat = flats.where((f) => f.id == bed.flatId).firstOrNull;
      if (flat == null) continue; // archived flat's beds not shown? but spec says flat-grouped
      vacantByFlat.putIfAbsent(bed.flatId, () => []).add(bed);
    }

    if (vacantByFlat.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No vacant beds.')),
      );
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final flat in flats)
            if (vacantByFlat.containsKey(flat.id)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: flatColorFor(flat.id),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(flat.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              for (final bed in (vacantByFlat[flat.id]!..sort((a,b)=>a.label.compareTo(b.label))))
                Card(
                  key: ValueKey('vacant-bed-${bed.id}'),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.bed_outlined),
                    title: Text(bed.label),
                    subtitle: Text(formatMoneyShort(bed.defaultMonthlyRent)),
                    trailing: const Icon(Icons.link),
                    onTap: () => Navigator.pushNamed(
                      context,
                      Routes.tenantsAssign,
                      arguments: bed.id,
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}
