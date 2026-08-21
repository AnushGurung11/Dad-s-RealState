import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/expense.dart';
import '../services/expense_service.dart';
import '../services/store_scope.dart';
import '../theme/flat_color.dart';
import '../utils/format.dart';

/// Expenses screen: flat picker + per-flat expense list grouped by month.
/// Supports add/edit/delete.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _selectedFlatId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final flats = [...store.flats];
    flats.sort((a, b) => a.name.compareTo(b.name));

    if (flats.isEmpty) {
      return const Center(child: Text('No flats yet. Add a flat first.'));
    }

    _selectedFlatId ??= flats.first.id;

    final selectedFlat = flats.firstWhere(
      (f) => f.id == _selectedFlatId,
      orElse: () => flats.first,
    );

    final service = ExpenseService(store);
    final grouped = service.groupedByMonth(selectedFlat.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          if (flats.length > 1)
            PopupMenuButton<String>(
              initialValue: selectedFlat.id,
              onSelected: (id) => setState(() => _selectedFlatId = id),
              itemBuilder: (_) => flats
                  .map((f) => PopupMenuItem(
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
                      ))
                  .toList(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: flatColorFor(selectedFlat.id),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(selectedFlat.name),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: grouped.isEmpty
          ? Center(child: Text('No expenses for ${selectedFlat.name} yet.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in grouped.entries)
                  _MonthSection(
                    month: entry.key,
                    expenses: entry.value,
                    onChanged: () => setState(() {}),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showExpenseDialog(selectedFlat.id),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showExpenseDialog(
    String flatId, {
    Expense? existing,
  }) async {
    final amountController =
        TextEditingController(text: existing?.amount.toString() ?? '');
    ExpenseCategory category = existing?.category ?? ExpenseCategory.electricity;
    DateTime date = existing?.date ?? DateTime.now();
    final noteController = TextEditingController(text: existing?.note ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add expense' : 'Edit expense'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: ExpenseCategory.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.label),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (AED)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => date = picked);
                  }
                },
                icon: const Icon(Icons.event_outlined),
                label: Text('Date: ${_dateText(date)}'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(
                      amountController.text.trim().replaceAll(',', '')) ??
                  0;
              if (amount <= 0) return;
              try {
                ExpenseService(StoreScope.of(context)).upsert(
                  flatId: flatId,
                  category: category,
                  amount: amount,
                  date: date,
                  note: noteController.text.trim().isEmpty
                      ? null
                      : noteController.text.trim(),
                  existingId: existing?.id,
                );
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                        content: Text(existing == null
                            ? 'Expense added'
                            : 'Expense updated')),
                  );
                setState(() {});
              } on ExpenseException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }

  String _dateText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Section for a month with its expenses.
class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.month,
    required this.expenses,
    required this.onChanged,
  });

  final String month;
  final List<Expense> expenses;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            _monthLabel(month),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final expense in expenses)
          _ExpenseTile(expense: expense, onChanged: onChanged),
      ],
    );
  }

  String _monthLabel(String m) {
    final parts = m.split('-');
    if (parts.length != 2) return m;
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final idx = int.tryParse(parts[1]) ?? 1;
    return '${names[idx - 1]} ${parts[0]}';
  }
}

/// Single expense row.
class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.onChanged});

  final Expense expense;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_iconFor(expense.category),
            color: Theme.of(context).colorScheme.primary),
        title: Text(formatMoneyShort(expense.amount)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_dateText(expense.date)),
            if (expense.note != null && expense.note!.isNotEmpty)
              Text(
                expense.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') {
              _showEditDialog(context);
            } else if (action == 'delete') {
              _confirmDelete(context);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _showEditDialog(context),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    // Find the ExpensesScreen ancestor and trigger its dialog
    final state = context.findAncestorStateOfType<_ExpensesScreenState>();
    if (state != null) {
      state._showExpenseDialog(expense.flatId, existing: expense);
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ExpenseService(StoreScope.of(context)).delete(expense.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                    const SnackBar(content: Text('Expense deleted')));
              onChanged();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ExpenseCategory c) {
    switch (c) {
      case ExpenseCategory.electricity:
        return Icons.bolt_outlined;
      case ExpenseCategory.water:
        return Icons.water_drop_outlined;
      case ExpenseCategory.gas:
        return Icons.local_fire_department_outlined;
      case ExpenseCategory.internet:
        return Icons.wifi_outlined;
      case ExpenseCategory.maintenance:
        return Icons.build_outlined;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  String _dateText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}