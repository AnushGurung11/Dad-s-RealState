import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/person.dart';
import '../services/store_scope.dart';
import '../services/tenant_rent_payment_service.dart';
import '../services/tenure_service.dart';
import '../utils/format.dart';
import '../widgets/tenant_picker_list.dart';

/// Tenant Rent Payment: searchable, flat-grouped list of active tenants with
/// this month's Paid/Unpaid badge on every row. Selecting one opens the
/// payment form — single month or multi-month prepayment.
class TenantRentPaymentScreen extends StatefulWidget {
  const TenantRentPaymentScreen({super.key});

  @override
  State<TenantRentPaymentScreen> createState() =>
      _TenantRentPaymentScreenState();
}

class _TenantRentPaymentScreenState extends State<TenantRentPaymentScreen> {
  void _refresh() => setState(() {});

  Future<void> _openPayDialog(Person person) async {
    final result = await showDialog<MultiMonthResult>(
      context: context,
      builder: (_) => _RentPayDialog(person: person),
    );
    if (result == null || !mounted) return;

    try {
      TenantRentPaymentService(StoreScope.of(context))
          .recordMultiMonthPayment(
        person: person,
        monthsPaying: result.months,
        firstAmount: result.firstAmount,
        firstDate: result.firstDate,
        futureAmounts: result.futureAmounts,
        description: result.description,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(result.months == 1
                ? 'Rent payment recorded'
                : '${result.months} months of rent recorded')));
      _refresh();
    } on PaymentException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Rent Payment')),
      body: TenantPickerList(
        includeArchived: false,
        emptyText: 'No active tenants.',
        searchHint: 'Search tenants',
        searchKey: const Key('tenant_payment_search_field'),
        showPaidBadge: true,
        onPersonTap: _openPayDialog,
      ),
    );
  }
}

/// What the multi-month form hands back on save.
class MultiMonthResult {
  const MultiMonthResult({
    required this.months,
    required this.firstAmount,
    required this.firstDate,
    this.futureAmounts,
    this.description,
  });

  final int months;
  final double firstAmount;
  final DateTime firstDate;
  final Map<int, double>? futureAmounts;
  final String? description;
}

/// Rent form. The amount is never pre-filled — the landlord types what was
/// actually collected. "Months paying for" (default 1) unlocks an editable
/// per-month preview before save.
class _RentPayDialog extends StatefulWidget {
  const _RentPayDialog({required this.person});

  final Person person;

  @override
  State<_RentPayDialog> createState() => _RentPayDialogState();
}

class _RentPayDialogState extends State<_RentPayDialog> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _months = 1;
  DateTime _date = DateTime.now();

  /// Edits to future months' amounts, keyed by month index.
  final Map<int, double> _futureAmounts = {};

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double? get _firstAmount =>
      double.tryParse(_amountController.text.trim().replaceAll(',', ''));

  String _dateText(DateTime date) => '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  List<PlannedMonthPayment> get _preview {
    if (_months < 1 || _firstAmount == null || _firstAmount! <= 0) {
      return const [];
    }
    try {
      return TenantRentPaymentService.planMonths(
        person: widget.person,
        monthsPaying: _months,
        firstAmount: _firstAmount!,
        firstDate: _date,
        futureAmounts: _futureAmounts,
      );
    } on PaymentException {
      return const [];
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime(_date.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  bool get _canSave =>
      _preview.isNotEmpty && _preview.every((p) => p.amount > 0);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final rent = widget.person.monthlyRent ?? 0;
    final balance = TenureService.remainingBalance(
      widget.person,
      rent,
      store.payments,
    );

    return AlertDialog(
      title: Text('Record rent — ${widget.person.name}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly rent ${formatMoneyShort(rent)} · '
              'Balance ${formatMoneySigned(balance)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('rent_amount_field'),
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount paid for month 1 (AED)',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
              ],
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('Months paying for')),
                IconButton(
                  key: const Key('months_minus'),
                  onPressed:
                      _months > 1 ? () => setState(() => _months--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_months',
                    key: const Key('months_value'),
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  key: const Key('months_plus'),
                  onPressed: () =>
                      setState(() {
                        _months++;
                        // A fresh future month starts from the default rent.
                        _futureAmounts.remove(_months - 1);
                      }),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Text('Paid date: ${_dateText(_date)}'),
            ),
            if (_months > 1) ...[
              const SizedBox(height: 12),
              Text('Preview — edit each month before saving:',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _preview.length,
                  itemBuilder: (context, index) {
                    final plan = _preview[index];
                    if (index == 0) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.event_available, size: 18),
                        title: Text(_dateText(plan.date)),
                        trailing: Text(formatMoneyShort(plan.amount)),
                      );
                    }
                    final controller = TextEditingController(
                      text: formatMoney(plan.amount),
                    );
                    return ListTile(
                      key: ValueKey('month_preview_$index'),
                      dense: true,
                      leading: const Icon(Icons.event_outlined, size: 18),
                      title: Text(_dateText(plan.date)),
                      trailing: SizedBox(
                        width: 110,
                        child: TextFormField(
                          key: Key('month_amount_$index'),
                          initialValue: controller.text,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*[.,]?\d*')),
                          ],
                          onChanged: (value) {
                            final parsed = double.tryParse(
                                value.trim().replaceAll(',', ''));
                            if (parsed != null) {
                              _futureAmounts[index] = parsed;
                            } else {
                              _futureAmounts.remove(index);
                            }
                            setState(() {});
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('rent_description_field'),
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. paid early, partial payment...',
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
          key: const Key('record_rent_payment'),
          onPressed: !_canSave
              ? null
              : () => Navigator.pop(
                  context,
                  MultiMonthResult(
                    months: _months,
                    firstAmount: _firstAmount!,
                    firstDate: _date,
                    futureAmounts:
                        _futureAmounts.isEmpty ? null : _futureAmounts,
                    description: _descriptionController.text.trim().isEmpty
                        ? null
                        : _descriptionController.text.trim(),
                  )),
          child: Text(_months == 1 ? 'Record payment' : 'Record $_months payments'),
        ),
      ],
    );
  }
}
