import 'package:flutter/material.dart';

import '../config.dart';
import '../models/bed.dart';
import '../models/flat.dart';
import '../models/person.dart';
import '../navigation/routes.dart';
import '../services/assignment_service.dart';
import '../services/bed_capacity_service.dart';
import '../services/payment_service.dart';
import '../services/store_scope.dart';
import '../utils/format.dart';
import '../utils/ids.dart';
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
    _tabController = TabController(length: 3, vsync: this);
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

  Future<void> _addBed() async {
    final store = StoreScope.of(context);
    final flatBeds = store.beds.where((b) => b.flatId == widget.flatId).toList();
    if (flatBeds.length >= BedCapacityService.maxBeds) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum ${BedCapacityService.maxBeds} beds reached')),
      );
      return;
    }

    // Find next available bed number
    var index = 1;
    while (flatBeds.any((b) => b.label == 'Bed $index')) {
      index++;
    }

    final defaultRent = flatBeds.isNotEmpty ? flatBeds.first.defaultMonthlyRent : 0.0;
    store.upsertBed(Bed(
      id: newId(),
      flatId: widget.flatId,
      label: 'Bed $index',
      defaultMonthlyRent: defaultRent,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bed added')),
      );
      _refresh();
    }
  }

  Future<void> _deleteBed(Bed bed) async {
    if (bed.isOccupied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete an occupied bed. Make it vacant first.')),
      );
      return;
    }

    final store = StoreScope.of(context);
    final flatBeds = store.beds.where((b) => b.flatId == widget.flatId).toList();
    if (flatBeds.length <= BedCapacityService.minBeds) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Minimum ${BedCapacityService.minBeds} beds required')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${bed.label}?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    store.deleteBed(bed.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${bed.label} deleted')),
    );
    _refresh();
  }

  Future<void> _makeVacant(Bed bed) async {
    if (!bed.isOccupied) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Make ${bed.label} vacant?'),
        content: const Text('This will unassign the current tenant from this bed. Their payment history is preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Make vacant')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final store = StoreScope.of(context);
    final service = AssignmentService(store);
    service.unassignTenant(bed.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${bed.label} is now vacant')),
    );
    _refresh();
  }

  Future<void> _reassignBed(Bed bed) async {
    if (!bed.isOccupied) return;

    final store = StoreScope.of(context);
    final person = _personFor(store.people, bed.tenantId);
    if (person == null) return;

    // Find all active flats with vacant beds (excluding current flat)
    final flatIdsWithVacancy = store.beds
        .where((b) => !b.isOccupied && b.flatId != widget.flatId)
        .map((b) => b.flatId)
        .toSet();
    final availableFlats = store.flats
        .where((f) => !f.archived && flatIdsWithVacancy.contains(f.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (availableFlats.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other flats with vacant beds available')),
      );
      return;
    }

    final selectedFlat = await showDialog<Flat>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Move ${person.name} to...'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableFlats.length,
            itemBuilder: (context, index) {
              final flat = availableFlats[index];
              final vacantCount = store.beds
                  .where((b) => b.flatId == flat.id && !b.isOccupied)
                  .length;
              return ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: Text(flat.name),
                subtitle: Text('$vacantCount vacant bed(s)'),
                onTap: () => Navigator.pop(ctx, flat),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
    if (selectedFlat == null || !mounted) return;

    // Show vacant beds in selected flat
    final vacantBeds = store.beds
        .where((b) => b.flatId == selectedFlat.id && !b.isOccupied)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    final selectedBed = await showDialog<Bed>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Select bed in ${selectedFlat.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: vacantBeds.length,
            itemBuilder: (context, index) {
              final b = vacantBeds[index];
              return ListTile(
                leading: const Icon(Icons.bed_outlined),
                title: Text(b.label),
                subtitle: Text('${formatMoneyShort(b.defaultMonthlyRent)}/mo'),
                onTap: () => Navigator.pop(ctx, b),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
    if (selectedBed == null || !mounted) return;

    // Unassign from current bed, then assign to new bed
    final service = AssignmentService(store);
    service.unassignTenant(bed.id);
    service.assignTenant(
      bed: selectedBed,
      person: person,
      deposit: 0, // No new deposit for reassignment
      joinDate: person.joinDate ?? DateTime.now(),
      plannedStayMonths: person.plannedStayMonths ?? 12,
      monthlyRent: person.monthlyRent,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${person.name} moved to ${selectedBed.label}')),
    );
    _refresh();
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
    final canAddBed = beds.length < BedCapacityService.maxBeds;

    return Scaffold(
      appBar: AppBar(
        title: Text(flat.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Beds'),
            Tab(text: 'Lease info'),
            Tab(text: 'Utilities'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Beds tab with add button
          Column(
            children: [
              Expanded(
                child: ListView.builder(
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
                      onDelete: bed.isOccupied ? null : () => _deleteBed(bed),
                      onMakeVacant: bed.isOccupied ? () => _makeVacant(bed) : null,
                      onReassign: bed.isOccupied ? () => _reassignBed(bed) : null,
                    );
                  },
                ),
              ),
              // Add bed button
              if (canAddBed)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    key: const Key('add_bed_detail'),
                    onPressed: _addBed,
                    icon: const Icon(Icons.add),
                    label: const Text('Add bed'),
                  ),
                ),
            ],
          ),
          _LeaseInfoTab(flat: flat),
          _UtilitiesTab(flat: flat),
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

class _UtilitiesTab extends StatelessWidget {
  const _UtilitiesTab({required this.flat});

  final Flat flat;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Utilities & Contacts',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
        const SizedBox(height: 12),
        _LeaseField(label: 'Landline number', value: flat.landlineNumber),
        _LeaseField(
            label: 'Landline registered name',
            value: flat.landlineRegisteredName),
        _LeaseField(label: 'Esewa number', value: flat.esewaNumber),
        _LeaseField(label: 'Wifi name', value: flat.wifiName),
        _LeaseField(label: 'Wifi password', value: flat.wifiPassword),
      ],
    );
  }
}

