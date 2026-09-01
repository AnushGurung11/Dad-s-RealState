// ignore_for_file: unused_element
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../models/expense.dart';
import '../models/flat.dart';
import '../models/lease_cheque_record.dart';
import '../services/expense_service.dart';
import '../services/store_scope.dart';
import '../theme/flat_color.dart';
import '../utils/format.dart';

/// Expenses screen: flat cards → per-flat expense list grouped by month.
/// Supports add/edit/delete with description.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String? _selectedFlatId;
  String _searchQuery = '';
  String? _searchYear;
  String? _searchMonth;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final allFlats = [...store.flats];
    allFlats.sort((a, b) => a.name.compareTo(b.name));
    final activeFlats = allFlats.where((f) => !f.archived).toList();
    final archivedFlats = allFlats.where((f) => f.archived).toList();

    // If a flat is selected, show its expenses
    if (_selectedFlatId != null) {
      return _buildExpenseList(store, activeFlats, archivedFlats);
    }

    // Otherwise show flat cards
    return _buildFlatCards(activeFlats, archivedFlats);
  }

  Widget _buildFlatCards(List<Flat> activeFlats, List<Flat> archivedFlats) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (activeFlats.isNotEmpty) ...[
            Text('Active',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final flat in activeFlats)
              _FlatExpenseCard(
                flat: flat,
                onTap: () => setState(() => _selectedFlatId = flat.id),
              ),
          ],
          if (archivedFlats.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Archived',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            for (final flat in archivedFlats)
              _FlatExpenseCard(
                flat: flat,
                archived: true,
                onTap: () => setState(() => _selectedFlatId = flat.id),
              ),
          ],
          if (activeFlats.isEmpty && archivedFlats.isEmpty)
            const Center(child: Text('No flats yet. Add a flat first.')),
        ],
      ),
    );
  }

  Widget _buildExpenseList(dynamic store, List<Flat> activeFlats, List<Flat> archivedFlats) {
    final selectedFlat = [...activeFlats, ...archivedFlats].firstWhere(
      (f) => f.id == _selectedFlatId,
      orElse: () => activeFlats.isNotEmpty ? activeFlats.first : archivedFlats.first,
    );

    final grouped = _groupedCombined(selectedFlat.id, store);

    // Apply search filter
    final filteredGrouped = <String, List<dynamic>>{};
    for (final entry in grouped.entries) {
      final parts = entry.key.split('-');
      final year = parts[0];
      final month = parts[1];

      // Year/month filter
      if (_searchYear != null && year != _searchYear) continue;
      if (_searchMonth != null && month != _searchMonth) continue;

      // Text search filter
      if (_searchQuery.isNotEmpty) {
        final matching = entry.value.where((item) {
          if (item is Expense) {
            return item.category.label.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (item.note?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                (item.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
          } else if (item is LeaseChequeRecord) {
            return item.ownerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (item.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
          }
          return false;
        }).toList();
        if (matching.isNotEmpty) {
          filteredGrouped[entry.key] = matching;
        }
      } else {
        filteredGrouped[entry.key] = entry.value;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedFlat.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _selectedFlatId = null;
            _searchQuery = '';
            _searchYear = null;
            _searchMonth = null;
          }),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search expenses...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _searchYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    hint: const Text('All'),
                    items: _availableYears(store, selectedFlat.id)
                        .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                    onChanged: (v) => setState(() => _searchYear = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _searchMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    hint: const Text('All'),
                    items: const [
                      DropdownMenuItem(value: '01', child: Text('Jan')),
                      DropdownMenuItem(value: '02', child: Text('Feb')),
                      DropdownMenuItem(value: '03', child: Text('Mar')),
                      DropdownMenuItem(value: '04', child: Text('Apr')),
                      DropdownMenuItem(value: '05', child: Text('May')),
                      DropdownMenuItem(value: '06', child: Text('Jun')),
                      DropdownMenuItem(value: '07', child: Text('Jul')),
                      DropdownMenuItem(value: '08', child: Text('Aug')),
                      DropdownMenuItem(value: '09', child: Text('Sep')),
                      DropdownMenuItem(value: '10', child: Text('Oct')),
                      DropdownMenuItem(value: '11', child: Text('Nov')),
                      DropdownMenuItem(value: '12', child: Text('Dec')),
                    ],
                    onChanged: (v) => setState(() => _searchMonth = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredGrouped.isEmpty
                ? Center(child: Text(_searchQuery.isNotEmpty || _searchYear != null || _searchMonth != null
                    ? 'No matching expenses.'
                    : 'No expenses for ${selectedFlat.name} yet.'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final entry in filteredGrouped.entries)
                        _CombinedMonthSection(
                          month: entry.key,
                          items: entry.value,
                          onChanged: () => setState(() {}),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1B9E3E),
        onPressed: () => _showExpenseDialog(selectedFlat.id),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<String> _availableYears(dynamic store, String flatId) {
    final years = <String>{};
    for (final e in store.expenses.where((Expense e) => e.flatId == flatId)) {
      years.add(e.date.year.toString());
    }
    for (final r in store.leaseChequeRecords.where((LeaseChequeRecord r) => r.flatId == flatId)) {
      years.add(r.dueDate.year.toString());
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  Map<String, List<dynamic>> _groupedCombined(String flatId, dynamic store) {
    final expenses = (store.expenses as List<Expense>).where((e) => e.flatId == flatId).toList();
    final leases = (store.leaseChequeRecords as List<LeaseChequeRecord>).where((r) => r.flatId == flatId).toList();
    final combined = <dynamic>[];
    combined.addAll(expenses);
    combined.addAll(leases);
    combined.sort((a, b) {
      final da = a is Expense ? a.date : (a as LeaseChequeRecord).paidDate;
      final db = b is Expense ? b.date : (b as LeaseChequeRecord).paidDate;
      return db.compareTo(da);
    });
    final map = <String, List<dynamic>>{};
    for (final item in combined) {
      final month = item is Expense ? monthKey(item.date) : (item as LeaseChequeRecord).month;
      map.putIfAbsent(month, () => []).add(item);
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, map[k]!)));
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
    final descriptionController = TextEditingController(text: existing?.description ?? '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add expense' : 'Edit expense'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
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
                    onChanged: (v) => setDialogState(() => category = v!),
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
                        setDialogState(() => date = picked);
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'e.g. paid in advance, split with tenant...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
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
                    description: descriptionController.text.trim().isEmpty
                        ? null
                        : descriptionController.text.trim(),
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
      ),
    );
  }

  String _dateText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _FlatExpenseCard extends StatelessWidget {
  const _FlatExpenseCard({
    required this.flat,
    required this.onTap,
    this.archived = false,
  });

  final Flat flat;
  final VoidCallback onTap;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: archived
                ? flatColorFor(flat.id).withValues(alpha: 0.4)
                : flatColorFor(flat.id),
            shape: BoxShape.circle,
          ),
        ),
        title: Text(flat.name,
            style: archived
                ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                : null),
        subtitle: Text(flat.address),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Combined month section showing both expenses and lease cheques interleaved.
class _CombinedMonthSection extends StatelessWidget {
  const _CombinedMonthSection({
    required this.month,
    required this.items,
    required this.onChanged,
  });

  final String month;
  final List<dynamic> items;
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
        for (final item in items)
          if (item is Expense)
            _ExpenseTile(expense: item, onChanged: onChanged)
          else if (item is LeaseChequeRecord)
            _LeaseExpenseTile(record: item, onChanged: onChanged),
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

class _LeaseExpenseTile extends StatelessWidget {
  const _LeaseExpenseTile({required this.record, required this.onChanged});

  final LeaseChequeRecord record;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Row(
          children: [
            Text(formatMoneyShort(record.amount)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Lease',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      )),
            ),
          ],
        ),
        subtitle: Text('Paid ${_dateText(record.paidDate)} · Due ${_dateText(record.dueDate)}'),
        trailing: const Icon(Icons.chevron_right, size: 16),
        isThreeLine: false,
      ),
    );
  }

  String _dateText(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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
            if (expense.effectiveDescription != null && expense.effectiveDescription!.isNotEmpty)
              Text(
                expense.effectiveDescription!,
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
