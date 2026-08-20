import 'package:flutter/material.dart';

import '../config.dart';
import '../models/expense.dart';
import '../models/flat.dart';
import '../services/json_store.dart';
import '../services/report_service.dart';
import '../utils/format.dart';
import '../utils/ids.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/net_amount_label.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.store,
    required this.initialMonth,
    required this.onMonthChanged,
    required this.onGoToFlats,
  });

  final JsonStore store;
  final String initialMonth;
  final ValueChanged<String> onMonthChanged;
  final VoidCallback onGoToFlats;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late String _month;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
  }

  DateTime _monthDate() {
    final parts = _month.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
  }

  void _shiftMonth(int delta) {
    setState(() {
      final date = DateTime(_monthDate().year, _monthDate().month + delta, 1);
      _month = monthKey(date);
      widget.onMonthChanged(_month);
    });
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _monthDate(),
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _month = monthKey(picked);
        widget.onMonthChanged(_month);
      });
    }
  }

  Future<void> _openExpenseForm(Expense? existing) async {
    final flats = widget.store.flats;
    final result = await showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExpenseForm(
        flats: flats,
        existing: existing,
        initialMonth: _month,
      ),
    );
    if (result == null) return;
    setState(() {
      widget.store.upsertExpense(result);
    });
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete expense?',
      detail: '${expense.category.label} · ${formatMoneyShort(expense.amount)} '
          'on ${expense.date.day}/${expense.date.month}/${expense.date.year}',
    );
    if (!confirmed) return;
    setState(() {
      widget.store.deleteExpense(expense.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final flats = store.flats;
    final monthLabel =
        '${_monthDate().year} · ${_monthDate().month.toString().padLeft(2, '0')}';

    final totals = ReportService.dashboardTotals(
      payments: store.payments,
      expenses: store.expenses,
      month: _month,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous month',
                  onPressed: () => _shiftMonth(-1),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickMonth,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      child: Text(
                        monthLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next month',
                  onPressed: () => _shiftMonth(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: flats.isEmpty
                ? EmptyState(
                    icon: Icons.assessment_outlined,
                    message: 'Add a flat to see financial reports.',
                    actionLabel: 'Go to Flats',
                    onAction: widget.onGoToFlats,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'All flats — $monthLabel',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _TotalsColumn(
                                      label: 'Income',
                                      value: formatMoneyShort(totals.income),
                                    ),
                                  ),
                                  Expanded(
                                    child: _TotalsColumn(
                                      label: 'Expenses',
                                      value: formatMoneyShort(totals.expenses),
                                    ),
                                  ),
                                  Expanded(
                                    child: _TotalsColumn(
                                      label: 'Net',
                                      valueWidget: NetAmountLabel(
                                        amount: totals.net,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final flat in flats) ...[
                        _FlatReportCard(
                          store: store,
                          flat: flat,
                          month: _month,
                          onAddExpense: () => _openExpenseForm(null),
                          onDeleteExpense: _deleteExpense,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TotalsColumn extends StatelessWidget {
  const _TotalsColumn({
    required this.label,
    this.value,
    this.valueWidget,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        valueWidget ??
            Text(
              value ?? '',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
      ],
    );
  }
}

class _FlatReportCard extends StatelessWidget {
  const _FlatReportCard({
    required this.store,
    required this.flat,
    required this.month,
    required this.onAddExpense,
    required this.onDeleteExpense,
  });

  final JsonStore store;
  final Flat flat;
  final String month;
  final VoidCallback onAddExpense;
  final ValueChanged<Expense> onDeleteExpense;

  @override
  Widget build(BuildContext context) {
    final summary = ReportService.flatSummary(
      payments: store.payments,
      expenses: store.expenses,
      flatId: flat.id,
      month: month,
    );
    final expenses = store.expenses
        .where((e) => e.flatId == flat.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    flat.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                NetAmountLabel(amount: summary.net),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TotalsColumn(
                    label: 'Income',
                    value: formatMoneyShort(summary.income),
                  ),
                ),
                Expanded(
                  child: _TotalsColumn(
                    label: 'Expenses',
                    value: formatMoneyShort(summary.expenses),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Expenses',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            if (expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No expenses recorded for this flat.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            else
              for (final expense in expenses)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_outlined, size: 20),
                  title: Text(
                    '${expense.category.label} · '
                    '${formatMoneyShort(expense.amount)}',
                  ),
                  subtitle: Text(
                    '${expense.date.day}/${expense.date.month}/${expense.date.year}'
                    '${expense.note == null || expense.note!.isEmpty ? '' : ' · ${expense.note}'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: 'Delete expense',
                    onPressed: () => onDeleteExpense(expense),
                  ),
                ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddExpense,
                icon: const Icon(Icons.add),
                label: const Text('Add expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm({
    required this.flats,
    required this.initialMonth,
    this.existing,
  });

  final List<Flat> flats;
  final String initialMonth;
  final Expense? existing;

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  String? _flatId;
  ExpenseCategory _category = ExpenseCategory.electricity;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final parts = widget.initialMonth.split('-');
    final monthStart = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
    _flatId = widget.existing?.flatId ?? widget.flats.firstOrNull?.id;
    _category = widget.existing?.category ?? ExpenseCategory.electricity;
    _date = widget.existing?.date ?? monthStart;
    _amount = TextEditingController(
      text: widget.existing == null
          ? ''
          : widget.existing!.amount.toStringAsFixed(0),
    );
    _note = TextEditingController(text: widget.existing?.note ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    Navigator.of(context).pop(
      Expense(
        id: widget.existing?.id ?? newId(),
        flatId: _flatId!,
        category: _category,
        amount: amount,
        date: _date ?? DateTime.now(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomInset + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Add expense' : 'Edit expense',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _flatId,
              decoration: const InputDecoration(
                labelText: 'Flat',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final flat in widget.flats)
                  DropdownMenuItem(value: flat.id, child: Text(flat.name)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _flatId = value);
              },
              validator: (_) => _flatId == null ? 'Select a flat' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final category in ExpenseCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: 'Rs. ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final parsed = double.tryParse(v?.trim() ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(
                _date == null
                    ? 'Pick date'
                    : 'Date: ${_date!.day}/${_date!.month}/${_date!.year}',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}