import 'package:flutter/material.dart';

import '../config.dart';
import '../models/payment.dart';
import '../models/person.dart';
import '../navigation/routes.dart';
import '../services/store_scope.dart';
import '../theme/flat_color.dart';
import '../widgets/person_avatar.dart';
import '../widgets/status_badge.dart';

/// Standalone Tenants page: every ACTIVE tenant (assigned or unassigned),
/// grouped by flat with the flat's color dot. Unassigned active tenants
/// appear in their own "Unassigned" section. Each row shows photo/avatar,
/// name, bed label (or "Unassigned" badge) and this month's payment status
/// (paid / partial / overdue). Add tenant + Assign live on this page as
/// buttons — no need to open the drawer.
class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

enum TenantPaymentStatus { paid, partial, overdue }

/// This month's rent status for one tenant, from their payment records.
TenantPaymentStatus paymentStatusFor(
    List<Payment> payments, String personId, String month) {
  final records = payments
      .where((p) =>
          p.personId == personId &&
          p.type == PaymentType.rent &&
          p.month == month)
      .toList();
  if (records.isEmpty) return TenantPaymentStatus.overdue;
  if (records.any((p) => p.status == PaymentStatus.partial)) {
    return TenantPaymentStatus.partial;
  }
  // Fully-paid records only count if they cover something; a record exists
  // and is fully paid → paid.
  return records.every((p) => p.status == PaymentStatus.paid)
      ? TenantPaymentStatus.paid
      : TenantPaymentStatus.overdue;
}

class _TenantsScreenState extends State<TenantsScreen> {
  String _query = '';
  String? _selectedFlatId;
  bool _fabExpanded = false;

  void _refresh() => setState(() {});

  Future<void> _openAdd() async {
    setState(() => _fabExpanded = false);
    await Navigator.pushNamed(context, Routes.tenantsAdd);
    if (mounted) _refresh();
  }

  Future<void> _openAssign() async {
    setState(() => _fabExpanded = false);
    await Navigator.pushNamed(context, Routes.tenantsAssign);
    if (mounted) _refresh();
  }

  Future<void> _openPerson(String id) async {
    await Navigator.pushNamed(context, Routes.tenantsDetail, arguments: id);
    if (mounted) _refresh();
  }

  StatusKind _statusKind(TenantPaymentStatus status) => switch (status) {
        TenantPaymentStatus.paid => StatusKind.success,
        TenantPaymentStatus.partial => StatusKind.warning,
        TenantPaymentStatus.overdue => StatusKind.danger,
      };

  String _statusLabel(TenantPaymentStatus status) => switch (status) {
        TenantPaymentStatus.paid => 'Paid',
        TenantPaymentStatus.partial => 'Partial',
        TenantPaymentStatus.overdue => 'Unpaid',
      };

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final month = monthKey(DateTime.now());

    final needle = _query.trim().toLowerCase();
    
    // All active people (assigned or unassigned)
    final allActivePeople = store.people
        .where((p) => p.status == PersonStatus.active)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    
    // Separate assigned and unassigned
    final assignedPeople = allActivePeople.where((p) => p.bedId != null).toList();
    final unassignedPeople = allActivePeople.where((p) => p.bedId == null).toList();
    
    // Filter both lists by search query and flat filter
    final filteredAssigned = assignedPeople.where((p) {
      if (_selectedFlatId != null && p.flatId != _selectedFlatId) return false;
      if (needle.isNotEmpty && !p.name.toLowerCase().contains(needle)) return false;
      return true;
    }).toList();
    final filteredUnassigned = unassignedPeople.where((p) {
      if (needle.isNotEmpty && !p.name.toLowerCase().contains(needle)) return false;
      return true;
    }).toList();

    final children = <Widget>[
      TextField(
        key: const Key('tenants_search_field'),
        decoration: const InputDecoration(
          hintText: 'Search tenants by name',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => _query = value),
      ),
      const SizedBox(height: 8),
    ];

    // Flat filter dropdown
    final activeFlats = store.flats.where((f) => !f.archived).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (activeFlats.length > 1) {
      children.add(
        DropdownButtonFormField<String>(
          key: const Key('tenants_flat_filter'),
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
            ...activeFlats.map(
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
      children.add(const SizedBox(height: 8));
    }

    final hasAnyTenants = assignedPeople.isNotEmpty || unassignedPeople.isNotEmpty;
    
    if (!hasAnyTenants) {
      children.add(Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(
            'No active tenants yet.\nAdd a tenant or assign someone to a bed.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ));
      return _buildWithFab(ListView(padding: const EdgeInsets.all(16), children: children));
    }

    final hasFiltered = filteredAssigned.isNotEmpty || filteredUnassigned.isNotEmpty;
    if (!hasFiltered) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text(
          'No tenants match "$_query".',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ));
      return _buildWithFab(ListView(padding: const EdgeInsets.all(16), children: children));
    }

    // Assigned tenants grouped by flat
    if (filteredAssigned.isNotEmpty) {
      final flatIds = filteredAssigned.map((p) => p.flatId).where((id) => id != null).cast<String>().toSet();
      final flats =
          store.flats.where((f) => flatIds.contains(f.id)).toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      for (final flat in flats) {
        children.add(Padding(
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
              Text(flat.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ));

        final peopleInFlat =
            filteredAssigned.where((p) => p.flatId == flat.id).toList()
              ..sort((a, b) => a.name.compareTo(b.name));

        for (final person in peopleInFlat) {
          final bed = store.beds
              .where((b) => b.id == person.bedId)
              .firstOrNull;
          final status = paymentStatusFor(store.payments, person.id, month);
          children.add(Card(
            key: ValueKey('tenant-row-${person.id}'),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading:
                  PersonAvatar(photoPath: person.photoPath, name: person.name),
              title: Text(person.name),
              subtitle: Text(bed == null ? '—' : 'Bed ${_bedNumber(bed.label)}'),
              trailing: StatusBadge(
                kind: _statusKind(status),
                label: _statusLabel(status),
              ),
              onTap: () => _openPerson(person.id),
            ),
          ));
        }
      }
    }

    // Unassigned tenants section
    if (filteredUnassigned.isNotEmpty) {
      children.add(Padding(
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
            Text('Unassigned',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ));

      for (final person in filteredUnassigned) {
        children.add(Card(
          key: ValueKey('tenant-row-${person.id}'),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading:
                PersonAvatar(photoPath: person.photoPath, name: person.name),
            title: Text(person.name),
            subtitle: const Text('Unassigned'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusBadge(
                  kind: StatusKind.neutral,
                  label: 'Unassigned',
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: ValueKey('assign-shortcut-${person.id}'),
                  tooltip: 'Assign',
                  icon: const Icon(Icons.link, size: 20),
                  onPressed: () async {
                    await Navigator.pushNamed(
                      context,
                      Routes.tenantsAssign,
                      arguments: person.id,
                    );
                    if (mounted) _refresh();
                  },
                ),
              ],
            ),
            onTap: () => _openPerson(person.id),
          ),
        ));
      }
    }

    return _buildWithFab(ListView(padding: const EdgeInsets.all(16), children: children));
  }

  Widget _buildWithFab(Widget body) {
    return Scaffold(
      body: Stack(
        children: [
          body,
          Positioned(
            right: 16,
            bottom: 80,
            child: _buildFab(),
          ),
        ],
      ),
    );
  }

  Widget _buildFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_fabExpanded) ...[
          FloatingActionButton.small(
            key: const Key('tenants_add_button'),
            heroTag: 'tenants_add_fab',
            backgroundColor: const Color(0xFF1B9E3E),
            onPressed: _openAdd,
            tooltip: 'Add tenant',
            child: const Icon(Icons.person_add_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            key: const Key('tenants_assign_button'),
            heroTag: 'tenants_assign_fab',
            backgroundColor: const Color(0xFF1B9E3E),
            onPressed: _openAssign,
            tooltip: 'Assign',
            child: const Icon(Icons.link),
          ),
          const SizedBox(height: 8),
        ],
        FloatingActionButton(
          key: const Key('tenants_fab'),
          heroTag: 'tenants_main_fab',
          backgroundColor: const Color(0xFF1B9E3E),
          onPressed: () => setState(() => _fabExpanded = !_fabExpanded),
          child: Icon(_fabExpanded ? Icons.close : Icons.add),
        ),
      ],
    );
  }

  /// "Bed 3" → "3"; tolerates custom labels by showing them verbatim.
  String _bedNumber(String label) {
    final match = RegExp(r'^\s*Bed\s+(\d+)\s*$', caseSensitive: false)
        .firstMatch(label);
    return match != null ? match.group(1)! : label;
  }
}
