import 'package:flutter/material.dart';

import '../config.dart';
import '../models/flat.dart';
import '../navigation/routes.dart';
import '../services/dashboard_service.dart';
import '../services/store_scope.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Dashboard: summary cards + who paid + next lease due.
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
      month: monthKey(DateTime.now()),
    );

    return RefreshIndicator(
      onRefresh: () async {
        // Store is reactive via setState in parent; just return
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCards(summary: summary),
          const SizedBox(height: 24),
          _WhoPaidSection(summary: summary),
          const SizedBox(height: 24),
          _NextLeaseSection(summary: summary),
        ],
      ),
    );
  }
}

/// Four summary cards in a 2x2 grid.
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
                value: '${summary.bedsOccupied}/${summary.bedsOccupied + summary.bedsVacant}',
                subtitle: '${summary.bedsOccupied} occupied · ${summary.bedsVacant} vacant',
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
              child: _StatCard(
                icon: Icons.trending_up_outlined,
                label: 'This Month Profit',
                value: formatMoneySigned(summary.monthProfit),
                subtitle: 'Expense ${formatMoneyShort(summary.monthExpense)}',
                valueStyle: TextStyle(
                  color: summary.monthProfit >= 0
                      ? Theme.of(context).extension<AppStatusColors>()!.success
                      : Theme.of(context).extension<AppStatusColors>()!.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ],
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
    this.valueStyle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final TextStyle? valueStyle;

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
                Text(label, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: valueStyle ?? Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Who paid this month" summary card.
class _WhoPaidSection extends StatelessWidget {
  const _WhoPaidSection({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final paid = summary.paidThisMonthCount;
    final total = summary.totalActiveTenantCount;
    final unpaid = total - paid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Who paid this month', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.check_circle_outlined,
                    color: Theme.of(context).extension<AppStatusColors>()!.success,
                    label: 'Paid',
                    value: paid.toString(),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.cancel_outlined,
                    color: Theme.of(context).extension<AppStatusColors>()!.danger,
                    label: 'Unpaid',
                    value: unpaid.toString(),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.people_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    label: 'Total',
                    value: total.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (unpaid > 0)
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, Routes.paymentsTenantRent),
                icon: const Icon(Icons.payments_outlined, size: 18),
                label: const Text('Collect rent'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Small stat for who-paid row.
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

/// Next lease payment due card.
class _NextLeaseSection extends StatelessWidget {
  const _NextLeaseSection({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final next = summary.nextLeasePayment;
    if (next == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Next lease payment', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('No lease cheques scheduled.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    // Find flat name from store
    final store = StoreScope.of(context);
    final flat = store.flats.firstWhere((f) => f.id == next.flatId, orElse: () => Flat(id: '', name: 'Unknown', address: '', createdAt: DateTime.now()));
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final daysUntil = next.nextDueDate.difference(today).inDays;
    final overdue = daysUntil < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Next lease payment', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (overdue)
                  Chip(
                    label: const Text('OVERDUE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    backgroundColor: Theme.of(context).extension<AppStatusColors>()!.danger,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(flat.name, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('${formatMoneyShort(next.amount)} · Due ${_dateText(next.nextDueDate)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              overdue ? '${-daysUntil} days overdue' : (daysUntil == 0 ? 'Due today' : 'in $daysUntil day${daysUntil == 1 ? '' : 's'}'),
              style: TextStyle(
                color: overdue ? Theme.of(context).extension<AppStatusColors>()!.danger : null,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, Routes.paymentsFlatLease),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: const Text('View all lease payments'),
            ),
          ],
        ),
      ),
    );
  }

  String _dateText(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}