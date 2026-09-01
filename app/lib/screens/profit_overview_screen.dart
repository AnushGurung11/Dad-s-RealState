// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

import '../config.dart';
import '../models/expense.dart';
import '../models/lease_cheque_record.dart';
import '../models/payment.dart';
import '../services/expense_aggregation_service.dart';
import '../services/report_service.dart';
import '../services/store_scope.dart';
import '../services/transaction_edit_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Profit overview: net profit + total expenses at top, per-flat breakdown list.
/// Tapping a flat opens a detail with Profit (rent/deposit) and Expense sections.
class ProfitOverviewScreen extends StatelessWidget {
  const ProfitOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final month = monthKey(DateTime.now());
    final flats = store.flats.where((f) => !f.archived).toList();

    double totalIncome = 0;
    double totalExpenses = 0;
    final summaries = <String, ({double income, double expenses, double net})>{};

    for (final flat in flats) {
      final income = ReportService.flatIncome(payments: store.payments, flatId: flat.id, month: month);
      final expenses = ExpenseAggregationService.totalExpensesForFlat(
        flatId: flat.id,
        month: month,
        expenses: store.expenses,
        leaseChequeRecords: store.leaseChequeRecords,
      );
      summaries[flat.id] = (income: income, expenses: expenses, net: income - expenses);
      totalIncome += income;
      totalExpenses += expenses;
    }

    final netProfit = totalIncome - totalExpenses;

    return Scaffold(
      appBar: AppBar(title: const Text('Profit Overview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This Month — $month',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _SummaryItem(label: 'Net Profit', amount: netProfit, isPositive: netProfit >= 0)),
                      const SizedBox(width: 16),
                      Expanded(child: _SummaryItem(label: 'Total Expenses', amount: totalExpenses, isPositive: false)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Per-flat breakdown
          Text('Per-Flat Breakdown',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (flats.isEmpty)
            const Text('No flats yet.')
          else
            for (final flat in flats)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  key: ValueKey('profit-flat-${flat.id}'),
                  title: Text(flat.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  subtitle: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Income: ${formatMoneyShort(summaries[flat.id]!.income)}', style: const TextStyle(color: Colors.green, fontSize: 12)),
                      Text('Expense: ${formatMoneyShort(summaries[flat.id]!.expenses)}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                      Text('Net: ${formatMoneyShort(summaries[flat.id]!.net)}',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: summaries[flat.id]!.net >= 0 ? Colors.green : Colors.red)),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _FlatProfitDetailScreen(flatId: flat.id, flatName: flat.name)),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.amount, required this.isPositive});

  final String label;
  final double amount;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppStatusColors>()!;
    final fg = isPositive ? colors.success : colors.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(formatMoneyShort(amount), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: fg)),
      ],
    );
  }
}

/// Detail screen for a single flat: shows Profit (rent/deposit) and Expense sections.
class _FlatProfitDetailScreen extends StatelessWidget {
  const _FlatProfitDetailScreen({required this.flatId, required this.flatName});

  final String flatId;
  final String flatName;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final month = monthKey(DateTime.now());

    // Rent + deposit payments for this flat this month
    final rentPayments = store.payments
        .where((p) => p.flatId == flatId && p.month == month)
        .toList()
      ..sort((a, b) => b.amountPaid.compareTo(a.amountPaid));

    // Expense records for this flat this month
    final expenses = store.expenses
        .where((e) => e.flatId == flatId && monthKey(e.date) == month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Lease cheque records for this flat this month
    final leaseRecords = store.leaseChequeRecords
        .where((r) => r.flatId == flatId && r.month == month)
        .toList()
      ..sort((a, b) => b.paidDate.compareTo(a.paidDate));

    final totalIncome = rentPayments.fold(0.0, (sum, p) => sum + p.amountPaid);
    final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount) +
        leaseRecords.fold(0.0, (sum, r) => sum + r.amount);

    return Scaffold(
      appBar: AppBar(title: Text('$flatName — $month')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profit section
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trending_up_outlined, size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('Profit', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(formatMoneyShort(totalIncome), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (rentPayments.isEmpty && leaseRecords.isEmpty)
                    const Text('No income this month.', style: TextStyle(color: Colors.grey))
                  else ...[
                    for (final p in rentPayments)
                      _TransactionRow(
                        type: p.type == PaymentType.deposit ? 'Deposit' : 'Rent',
                        amount: p.amountPaid,
                        isIncome: true,
                        date: '${p.month}',
                        onEdit: () => _editPayment(context, p),
                        onDelete: () => _deletePayment(context, p.id),
                      ),
                    for (final r in leaseRecords)
                      _TransactionRow(
                        type: 'Lease',
                        amount: r.amount,
                        isIncome: false,
                        date: '${r.paidDate.year}-${r.paidDate.month.toString().padLeft(2, '0')}-${r.paidDate.day.toString().padLeft(2, '0')}',
                        onEdit: () => _editLeaseRecord(context, r),
                        onDelete: () => _deleteLeaseRecord(context, r.id),
                      ),
                  ],
                ],
              ),
            ),
          ),
          // Expense section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text('Expense', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(formatMoneyShort(totalExpenses), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (expenses.isEmpty)
                    const Text('No expenses this month.', style: TextStyle(color: Colors.grey))
                  else
                    for (final e in expenses)
                      _TransactionRow(
                        type: e.category.label,
                        amount: e.amount,
                        isIncome: false,
                        date: '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}',
                        onEdit: () => _editExpense(context, e),
                        onDelete: () => _deleteExpense(context, e.id),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPayment(BuildContext context, Payment p) async {
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
    if (result != null && result > 0 && context.mounted) {
      try {
        await TransactionEditService(StoreScope.of(context)).editPayment(p.id, amount: result);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment updated')));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _deletePayment(BuildContext context, String id) async {
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
    if (confirmed != true || !context.mounted) return;
    try {
      await TransactionEditService(StoreScope.of(context)).deletePayment(id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _editLeaseRecord(BuildContext context, LeaseChequeRecord r) async {
    final controller = TextEditingController(text: r.amount.toString());
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
    if (result != null && result > 0 && context.mounted) {
      try {
        await TransactionEditService(StoreScope.of(context)).editLeaseChequeRecord(r.id, amount: result);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lease payment updated')));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _deleteLeaseRecord(BuildContext context, String id) async {
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
    if (confirmed != true || !context.mounted) return;
    try {
      await TransactionEditService(StoreScope.of(context)).deleteLeaseChequeRecord(id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _editExpense(BuildContext context, Expense e) async {
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
    if (result != null && result > 0 && context.mounted) {
      try {
        await TransactionEditService(StoreScope.of(context)).editExpense(e.id, amount: result);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense updated')));
      } catch (e2) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e2')));
      }
    }
  }

  Future<void> _deleteExpense(BuildContext context, String id) async {
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
    if (confirmed != true || !context.mounted) return;
    try {
      await TransactionEditService(StoreScope.of(context)).deleteExpense(id);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.type,
    required this.amount,
    required this.isIncome,
    required this.date,
    required this.onEdit,
    required this.onDelete,
  });

  final String type;
  final double amount;
  final bool isIncome;
  final String date;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppStatusColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isIncome ? colors.success.withValues(alpha: 0.15) : colors.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(type, style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isIncome ? colors.success : colors.danger,
            )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${isIncome ? '+' : '-'}${formatMoneyShort(amount)}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: isIncome ? colors.success : colors.danger, fontSize: 13)),
                Text(date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
