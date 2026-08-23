import 'package:flutter/material.dart';

import '../config.dart';
import '../models/payment.dart';
import '../models/person.dart';
import '../navigation/routes.dart';
import '../services/store_scope.dart';
import '../theme/flat_color.dart';
import '../widgets/person_avatar.dart';
import '../widgets/status_badge.dart';

/// Standalone Tenants page: every ACTIVE tenant, grouped by flat with the
/// flat's color dot. Each row shows photo/avatar, name, bed label and this
/// month's payment status (paid / partial / overdue). Add tenant + Assign
/// live on this page as buttons — no need to open the drawer.
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

  void _refresh() => setState(() {});

  Future<void> _openAdd() async {
    await Navigator.pushNamed(context, Routes.tenantsAdd);
    if (mounted) _refresh();
  }

  Future<void> _openAssign() async {
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
    final activeTenants = store.people
        .where((p) => p.bedId != null && p.status == PersonStatus.active)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final filtered = needle.isEmpty
        ? activeTenants
        : activeTenants
            .where((p) => p.name.toLowerCase().contains(needle))
            .toList();

    final children = <Widget>[
      Row(
        key: const Key('tenants_actions'),
        children: [
          Expanded(
            child: FilledButton.icon(
              key: const Key('tenants_add_button'),
              onPressed: _openAdd,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add tenant'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('tenants_assign_button'),
              onPressed: _openAssign,
              icon: const Icon(Icons.link),
              label: const Text('Assign'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
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

    if (activeTenants.isEmpty) {
      children.add(Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(
            'No active tenants yet.\nAssign someone to a bed to see them here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ));
      return Scaffold(
          body: ListView(padding: const EdgeInsets.all(16), children: children));
    }

    if (filtered.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text(
          'No tenants match "$_query".',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ));
      return Scaffold(
          body: ListView(padding: const EdgeInsets.all(16), children: children));
    }

    // Group by flat via each bed's flatId.
    final flatIds = filtered.map((p) => p.flatId).toSet();
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
          filtered.where((p) => p.flatId == flat.id).toList()
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

    return Scaffold(
      body: ListView(padding: const EdgeInsets.all(16), children: children),
    );
  }

  /// "Bed 3" → "3"; tolerates custom labels by showing them verbatim.
  String _bedNumber(String label) {
    final match = RegExp(r'^\s*Bed\s+(\d+)\s*$', caseSensitive: false)
        .firstMatch(label);
    return match != null ? match.group(1)! : label;
  }
}
