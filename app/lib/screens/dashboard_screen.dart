import 'package:flutter/material.dart';

import '../config.dart';
import '../navigation/routes.dart';
import '../services/dashboard_service.dart';
import '../services/store_scope.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Dashboard: summary cards + two navigation buttons (Lease Payment /
/// Rent Payment). The "who's paid" summary and next-lease teaser are gone —
/// the buttons lead straight to the authoritative, badge-annotated lists.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final summary = DashboardService().build(
      flats: store.flats,
      beds: store.beds,
      people: store.people,
      payments: store.payments,
      expenses: store.expenses,
      leaseSettings: store.leaseChequeSettings,
      leaseChequeRecords: store.leaseChequeRecords,
      month: monthKey(DateTime.now()),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryCards(summary: summary),
        const SizedBox(height: 24),
        const _QuickLinks(),
      ],
    );
  }
}

/// Four summary cards in a 2x2 grid. The profit figure scales down inside a
/// [FittedBox] so huge values never overflow the card's bounds.
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.apartment_outlined,
                label: 'Flats',
                value: summary.flatsCount.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.bed_outlined,
                label: 'Beds',
                value:
                    '${summary.bedsOccupied}/${summary.bedsOccupied + summary.bedsVacant}',
                subtitle:
                    '${summary.bedsOccupied} occupied · ${summary.bedsVacant} vacant',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.people_outlined,
                label: 'Active Tenants',
                value: summary.activePeopleCount.toString(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ProfitCard(profit: summary.monthProfit),
            ),
          ],
        ),
      ],
    );
  }
}

/// This Month Profit card: compact formatting + FittedBox scale-down so both
/// very large positives and negatives always fit.
class _ProfitCard extends StatelessWidget {
  const _ProfitCard({required this.profit});

  final double profit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppStatusColors>()!;
    return Card(
      key: const Key('profit_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_outlined,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('This Month Profit',
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            // ScaleDown keeps even "-999999 AED" fully visible at small widths.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatMoneyCompact(profit),
                key: const Key('profit_value'),
                style: TextStyle(
                  color: profit >= 0 ? colors.success : colors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual stat card.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The two payment entry points replacing the old next-lease / who-paid
/// sections.
class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const Key('dashboard_lease_payment_button'),
            onPressed: () =>
                Navigator.pushNamed(context, Routes.paymentsFlatLease),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Lease Payment'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            key: const Key('dashboard_rent_payment_button'),
            onPressed: () =>
                Navigator.pushNamed(context, Routes.paymentsTenantRent),
            icon: const Icon(Icons.person_outlined),
            label: const Text('Rent Payment'),
          ),
        ),
      ],
    );
  }
}
