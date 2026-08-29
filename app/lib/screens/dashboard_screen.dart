import 'package:flutter/material.dart';

import '../config.dart';
import '../models/lease_cheque_record.dart';
import '../models/payment.dart';
import '../models/expense.dart';
import '../navigation/routes.dart';
import '../services/dashboard_service.dart';
import '../services/store_scope.dart';
import '../services/transaction_edit_service.dart';
import '../theme/app_theme.dart';
import '../utils/duration_format.dart';
import '../utils/format.dart';

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
        _SummaryGrid(summary: summary),
        const SizedBox(height: 16),
        _NextLeaseDueCard(summary: summary),
        const SizedBox(height: 24),
        const _RecentTransactionsSection(),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                key: const Key('dashboard_flats_card'),
                icon: Icons.apartment_outlined,
                label: 'Flats',
                value: summary.flatsCount.toString(),
                onTap: () => Navigator.pushNamed(context, Routes.flats),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                key: const Key('dashboard_occupancy_card'),
                icon: Icons.bed_outlined,
                label: 'Occupancy',
                value: '${summary.bedsOccupied}/${summary.bedsOccupied + summary.bedsVacant}',
                subtitle: '${summary.bedsOccupied} occupied · ${summary.bedsVacant} vacant',
                onTap: () => Navigator.pushNamed(context, Routes.vacantBeds),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ProfitCard(
                profit: summary.monthProfit,
                onTap: () => Navigator.pushNamed(context, Routes.financialActivity),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                key: const Key('dashboard_expenses_card'),
                icon: Icons.receipt_long_outlined,
                label: 'Expenses',
                value: formatMoneyShort(summary.monthExpense),
                onTap: () => Navigator.pushNamed(context, Routes.financialActivity),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatCard(
          key: const Key('dashboard_outstanding_card'),
          icon: Icons.warning_amber_outlined,
          label: 'Outstanding',
          value: '${summary.totalActiveTenantCount - summary.paidThisMonthCount}',
          subtitle: 'tenants unpaid this month',
          onTap: () => Navigator.pushNamed(context, Routes.tenants),
        ),
      ],
    );
  }
}

class _ProfitCard extends StatelessWidget {
  const _ProfitCard({required this.profit, this.onTap});

  final double profit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppStatusColors>()!;
    return Card(
      key: const Key('profit_card'),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.trending_up_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Profit', style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 8),
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
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NextLeaseDueCard extends StatelessWidget {
  const _NextLeaseDueCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final next = summary.nextLeasePayment;
    final statusColors = Theme.of(context).extension<AppStatusColors>()!;

    if (next == null) {
      return Card(
        key: const Key('next_lease_due_card'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Next Lease Due', style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              const SizedBox(height: 8),
              Text('No upcoming lease payments',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    final flat = store.flats.where((f) => f.id == next.flatId).firstOrNull;
    final dueDate = DateTime(next.nextDueDate.year, next.nextDueDate.month, next.nextDueDate.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final days = dueDate.difference(today).inDays;
    final remaining = formatRemaining(days);
    final isOverdue = days < 0;

    Color dueColor = statusColors.neutral;
    if (days < 0 || days <= 7) dueColor = statusColors.danger;
    else if (days <= 30) dueColor = statusColors.warning;

    return Card(
      key: const Key('next_lease_due_card'),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, Routes.paymentsFlatLease),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Next Lease Due', style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 8),
              Text(flat?.name ?? 'Unknown flat',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${formatMoneyShort(next.amount)} · Due ${_dateText(next.nextDueDate)}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                remaining,
                style: TextStyle(color: dueColor, fontWeight: FontWeight.w700, fontSize: 13),
                key: const Key('next_lease_remaining'),
              ),
              if (isOverdue)
                Text('Overdue',
                    style: TextStyle(color: statusColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  String _dateText(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _RecentTransactionsSection extends StatelessWidget {
  const _RecentTransactionsSection();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = _buildRecentTransactions(store);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Transactions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text('No transactions yet.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))
        else
          ...items.map((item) => _TransactionRow(item: item)),
      ],
    );
  }

  List<_TxItem> _buildRecentTransactions(dynamic store) {
    final payments = store.payments as List<Payment>;
    final expenses = store.expenses as List<Expense>;
    final leases = store.leaseChequeRecords as List<LeaseChequeRecord>;
    final flats = store.flats as List<dynamic>;
    final people = store.people as List<dynamic>;

    String flatName(String flatId) => flats.where((f) => f.id == flatId).firstOrNull?.name ?? flatId;
    String personName(String personId) => people.where((p) => p.id == personId).firstOrNull?.name ?? personId;

    final items = <_TxItem>[];
    for (final p in payments) {
      final date = DateTime.tryParse('${p.month}-01') ?? DateTime.now();
      items.add(_TxItem(
        id: p.id,
        type: p.type == PaymentType.deposit ? 'Deposit' : 'Rent',
        context: '${personName(p.personId)} · ${flatName(p.flatId)}',
        amount: p.amountPaid,
        isIncome: true,
        date: date,
        raw: p,
        kind: _TxKind.payment,
      ));
    }
    for (final e in expenses) {
      items.add(_TxItem(
        id: e.id,
        type: e.category.label,
        context: flatName(e.flatId),
        amount: e.amount,
        isIncome: false,
        date: e.date,
        raw: e,
        kind: _TxKind.expense,
      ));
    }
    for (final l in leases) {
      items.add(_TxItem(
        id: l.id,
        type: 'Lease',
        context: flatName(l.flatId),
        amount: l.amount,
        isIncome: false,
        date: l.paidDate,
        raw: l,
        kind: _TxKind.lease,
      ));
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items.take(15).toList();
  }
}

enum _TxKind { payment, expense, lease }

class _TxItem {
  _TxItem({
    required this.id,
    required this.type,
    required this.context,
    required this.amount,
    required this.isIncome,
    required this.date,
    required this.raw,
    required this.kind,
  });

  final String id;
  final String type;
  final String context;
  final double amount;
  final bool isIncome;
  final DateTime date;
  final dynamic raw;
  final _TxKind kind;
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.item});

  final _TxItem item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppStatusColors>()!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: item.isIncome ? colors.success.withValues(alpha: 0.15) : colors.danger.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(item.type,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: item.isIncome ? colors.success : colors.danger,
              )),
        ),
        title: Row(
          children: [
            Expanded(child: Text(item.context, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
            Text(
              '${item.isIncome ? '+' : '-'}${formatMoneyShort(item.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: item.isIncome ? colors.success : colors.danger,
                fontSize: 13,
              ),
            ),
          ],
        ),
        subtitle: Text('${item.date.year}-${item.date.month.toString().padLeft(2, '0')}-${item.date.day.toString().padLeft(2, '0')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('edit-${item.id}'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              onPressed: () => _onEdit(context),
            ),
            IconButton(
              key: ValueKey('delete-${item.id}'),
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Delete',
              onPressed: () => _onDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onEdit(BuildContext context) async {
    final store = StoreScope.of(context);
    final service = TransactionEditService(store);
    try {
      if (item.kind == _TxKind.payment) {
        final p = item.raw as Payment;
        final controller = TextEditingController(text: p.amountPaid.toString());
        final result = await showDialog<double>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Edit payment'),
            content: TextFormField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Amount (AED)', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)), child: const Text('Save')),
            ],
          ),
        );
        if (result != null && result > 0) {
          await service.editPayment(p.id, amount: result);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment updated')));
            (context as Element).markNeedsBuild();
          }
        }
      } else if (item.kind == _TxKind.expense) {
        final e = item.raw as Expense;
        final controller = TextEditingController(text: e.amount.toString());
        final result = await showDialog<double>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Edit expense'),
            content: TextFormField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Amount (AED)', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)), child: const Text('Save')),
            ],
          ),
        );
        if (result != null && result > 0) {
          await service.editExpense(e.id, amount: result);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense updated')));
            (context as Element).markNeedsBuild();
          }
        }
      } else if (item.kind == _TxKind.lease) {
        final l = item.raw as LeaseChequeRecord;
        final controller = TextEditingController(text: l.amount.toString());
        final result = await showDialog<double>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Edit lease payment'),
            content: TextFormField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Amount (AED)', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)), child: const Text('Save')),
            ],
          ),
        );
        if (result != null && result > 0) {
          await service.editLeaseChequeRecord(l.id, amount: result);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lease payment updated')));
            (context as Element).markNeedsBuild();
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _onDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: const Text('This will be audited and cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final store = StoreScope.of(context);
    final service = TransactionEditService(store);
    try {
      if (item.kind == _TxKind.payment) {
        await service.deletePayment(item.id);
      } else if (item.kind == _TxKind.expense) {
        await service.deleteExpense(item.id);
      } else if (item.kind == _TxKind.lease) {
        await service.deleteLeaseChequeRecord(item.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
        (context as Element).markNeedsBuild();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}
