import 'package:flutter/material.dart';

import '../config.dart';
import '../models/expense.dart';
import '../models/lease_cheque_record.dart';
import '../models/payment.dart';
import '../services/expense_aggregation_service.dart';
import '../services/report_service.dart';
import '../services/store_scope.dart';
import '../services/transaction_edit_service.dart';
import '../utils/format.dart';

/// Financial Activity screen: per-flat grouped summary at top + full ledger below.
class FinancialActivityScreen extends StatelessWidget {
  const FinancialActivityScreen({super.key, this.initialFlatId});

  final String? initialFlatId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final month = monthKey(DateTime.now());
    final allFlats = store.flats.where((f) => !f.archived).toList();
    final flats = initialFlatId == null
        ? allFlats
        : allFlats.where((f) => f.id == initialFlatId).toList();

    // Grouped summary per flat
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
    }

    final allTransactions = _buildTransactions(store);

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Activity')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Per-flat grouped summary
          Text('Per-Flat Breakdown — $month',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final flat in flats)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                key: Key('flat-summary-${flat.id}'),
                title: Text(flat.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Income: ${formatMoneyShort(summaries[flat.id]!.income)}', style: const TextStyle(color: Colors.green, fontSize: 12)),
                    Text('Expenses: ${formatMoneyShort(summaries[flat.id]!.expenses)}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                    Text('Net: ${formatMoneyShort(summaries[flat.id]!.net)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: summaries[flat.id]!.net >= 0 ? Colors.green : Colors.red)),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Income: ${formatMoneyShort(summaries[flat.id]!.income)}', style: Theme.of(context).textTheme.bodySmall),
                        Text('Expenses: ${formatMoneyShort(summaries[flat.id]!.expenses)}', style: Theme.of(context).textTheme.bodySmall),
                        Text('Net: ${formatMoneyShort(summaries[flat.id]!.net)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 32),
          Text('All Transactions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (allTransactions.isEmpty)
            const Text('No transactions yet.')
          else
            for (final tx in allTransactions)
              _TransactionTile(tx: tx),
        ],
      ),
    );
  }

  List<_Tx> _buildTransactions(dynamic store) {
    final payments = store.payments as List<Payment>;
    final expenses = store.expenses as List<Expense>;
    final leases = store.leaseChequeRecords as List<LeaseChequeRecord>;
    final list = <_Tx>[];
    for (final p in payments) {
      if (initialFlatId != null && p.flatId != initialFlatId) continue;
      list.add(_Tx(
          id: p.id,
          type: p.type == PaymentType.deposit ? 'Deposit' : 'Rent',
          amount: p.amountPaid,
          isIncome: true,
          date: DateTime.tryParse('${p.month}-01') ?? DateTime.now(),
          kind: 'payment',
          raw: p));
    }
    for (final e in expenses) {
      if (initialFlatId != null && e.flatId != initialFlatId) continue;
      list.add(_Tx(id: e.id, type: e.category.label, amount: e.amount, isIncome: false, date: e.date, kind: 'expense', raw: e));
    }
    for (final l in leases) {
      if (initialFlatId != null && l.flatId != initialFlatId) continue;
      list.add(_Tx(id: l.id, type: 'Lease', amount: l.amount, isIncome: false, date: l.paidDate, kind: 'lease', raw: l));
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}

class _Tx {
  _Tx({required this.id, required this.type, required this.amount, required this.isIncome, required this.date, required this.kind, required this.raw});
  final String id;
  final String type;
  final double amount;
  final bool isIncome;
  final DateTime date;
  final String kind;
  final dynamic raw;
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});
  final _Tx tx;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: tx.isIncome ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(tx.type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tx.isIncome ? Colors.green : Colors.red)),
        ),
        title: Text('${tx.isIncome ? '+' : '-'}${formatMoneyShort(tx.amount)}'),
        subtitle: Text('${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('edit-${tx.id}'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () async {
                final store = StoreScope.of(context);
                final service = TransactionEditService(store);
                // Simple amount edit
                final controller = TextEditingController(text: tx.amount.toString());
                final amt = await showDialog<double>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Edit'),
                    content: TextFormField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)), child: const Text('Save')),
                    ],
                  ),
                );
                if (amt != null && context.mounted) {
                  try {
                    if (tx.kind == 'payment') await service.editPayment(tx.id, amount: amt);
                    if (tx.kind == 'expense') await service.editExpense(tx.id, amount: amt);
                    if (tx.kind == 'lease') await service.editLeaseChequeRecord(tx.id, amount: amt);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated')));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
            ),
            IconButton(
              key: ValueKey('delete-${tx.id}'),
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete?'),
                    content: const Text('Audited.'),
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
                  if (tx.kind == 'payment') await service.deletePayment(tx.id);
                  if (tx.kind == 'expense') await service.deleteExpense(tx.id);
                  if (tx.kind == 'lease') await service.deleteLeaseChequeRecord(tx.id);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
