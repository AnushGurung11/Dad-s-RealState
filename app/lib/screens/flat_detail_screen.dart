import 'package:flutter/material.dart';

import '../config.dart';
import '../models/bed.dart';
import '../models/flat.dart';
import '../models/person.dart';
import '../navigation/routes.dart';
import '../services/payment_service.dart';
import '../services/store_scope.dart';
import '../utils/format.dart';
import '../widgets/bed_row.dart';

/// Flat detail: two tabs. "Beds" (default) lists every bed with its occupancy
/// state; "Lease info" shows the contract fields read-only — editing happens
/// from the Edit flow on the main Flats page, not here.
class FlatDetailScreen extends StatefulWidget {
  const FlatDetailScreen({super.key, required this.flatId});

  final String flatId;

  @override
  State<FlatDetailScreen> createState() => _FlatDetailScreenState();
}

class _FlatDetailScreenState extends State<FlatDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<Bed> _bedsFor(List<Bed> beds) {
    final flatBeds =
        beds.where((b) => b.flatId == widget.flatId).toList(growable: false);
    flatBeds.sort((a, b) => a.label.compareTo(b.label));
    return flatBeds;
  }

  Person? _personFor(List<Person> people, String? id) =>
      id == null ? null : people.where((p) => p.id == id).firstOrNull;

  /// Vacant beds jump straight into the assign flow with the bed preselected;
  /// occupied beds open the occupant's detail.
  Future<void> _onBedTap(Bed bed) async {
    if (!bed.isOccupied) {
      await Navigator.pushNamed(context, Routes.tenantsAssign,
          arguments: bed.id);
    } else {
      await Navigator.pushNamed(context, Routes.tenantsDetail,
          arguments: bed.tenantId);
    }
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final flat =
        store.flats.where((f) => f.id == widget.flatId).firstOrNull;
    if (flat == null) {
      return const Scaffold(body: Center(child: Text('Flat not found.')));
    }

    final now = DateTime.now();
    final overdueIds = PaymentService.overdueTenants(
      payments: store.payments,
      people: store.people,
      month: monthKey(now),
    ).map((p) => p.id).toSet();

    final beds = _bedsFor(store.beds);

    return Scaffold(
      appBar: AppBar(
        title: Text(flat.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Beds'),
            Tab(text: 'Lease info'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: beds.length,
            itemBuilder: (context, index) {
              final bed = beds[index];
              final occupant = _personFor(store.people, bed.tenantId);
              return BedRow(
                key: ValueKey(bed.id),
                bed: bed,
                occupantName: occupant?.name,
                occupantPhotoPath: occupant?.photoPath,
                isOverdue:
                    occupant != null && overdueIds.contains(occupant.id),
                onTap: () => _onBedTap(bed),
              );
            },
          ),
          _LeaseInfoTab(flat: flat),
        ],
      ),
    );
  }
}

class _LeaseInfoTab extends StatelessWidget {
  const _LeaseInfoTab({required this.flat});

  final Flat flat;

  @override
  Widget build(BuildContext context) {
    String? dateText(DateTime? date) => date == null
        ? null
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LeaseField(label: 'Address', value: flat.address),
        _LeaseField(
          label: 'Flat registered on',
          value: dateText(flat.registeredDate),
        ),
        _LeaseField(label: 'Contract person', value: flat.contractPerson),
        _LeaseField(
          label: 'Yearly rent',
          value: flat.yearlyRent == null
              ? null
              : formatMoneyShort(flat.yearlyRent!),
        ),
      ],
    );
  }
}

class _LeaseField extends StatelessWidget {
  const _LeaseField({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

