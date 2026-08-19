import 'package:flutter/material.dart';

import '../config.dart';
import '../models/payment.dart';
import '../models/person.dart';
import '../services/json_store.dart';
import '../services/payment_service.dart';
import '../utils/format.dart';
import '../utils/ids.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
    required this.store,
    required this.initialMonth,
    required this.onMonthChanged,
  });

  final JsonStore store;
  final String initialMonth;
  final ValueChanged<String> onMonthChanged;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late String _month;
  PaymentStatus? _filter;

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
      lastDate: DateTime(now.year, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _month = monthKey(picked);
        widget.onMonthChanged(_month);
      });
    }
  }

  Future<void> _openAddPayment() async {
    final result = await showModalBottomSheet<Payment>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentForm(store: widget.store, month: _month),
    );
    if (result == null) return;
    setState(() {
      widget.store.upsertPayment(result);
    });
  }

  Future<void> _markPartial(Payment payment) async {
    final controller = TextEditingController(
      text: payment.amountPaid.toStringAsFixed(0),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Partial payment for ${payment.month}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Amount paid',
            prefixText: 'Rs. ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null) return;
              Navigator.pop(context, parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (amount == null) return;
    setState(() {
      widget.store.upsertPayment(
        PaymentService.markPartial(payment, amount: amount),
      );
    });
  }

  String _personName(String personId) {
    final match = widget.store.people.where((p) => p.id == personId);
    return match.isEmpty ? 'Unknown tenant' : match.first.name;
  }

  String _bedLabel(String bedId) {
    final match = widget.store.beds.where((b) => b.id == bedId);
    return match.isEmpty ? 'Unknown bed' : match.first.label;
  }

  String _flatName(String flatId) {
    final match = widget.store.flats.where((f) => f.id == flatId);
    return match.isEmpty ? '' : match.first.name;
  }

  @override
  Widget build(BuildContext context) {
    var payments =
        widget.store.payments.where((p) => p.month == _month).toList()..sort(
          (a, b) => _personName(a.personId).compareTo(_personName(b.personId)),
        );

    if (_filter != null) {
      payments = payments.where((p) => p.status == _filter).toList();
    }

    final monthLabel =
        '${_monthDate().year} · ${_monthDate().month.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'payments-fab',
        onPressed: _openAddPayment,
        icon: const Icon(Icons.add),
        label: const Text('Add payment'),
      ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in [
                    (null, 'All'),
                    (PaymentStatus.paid, 'Paid'),
                    (PaymentStatus.partial, 'Partial'),
                    (PaymentStatus.unpaid, 'Unpaid'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(entry.$2),
                        selected: _filter == entry.$1,
                        onSelected: (_) => setState(() => _filter = entry.$1),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: payments.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: _filter == null
                        ? 'No payments recorded for $_month. Add your first payment.'
                        : 'No ${_filter!.name} payments for $_month.',
                    actionLabel: 'Add payment',
                    onAction: _openAddPayment,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                    itemCount: payments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final payment = payments[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: const Icon(Icons.person_outline),
                          ),
                          title: Text(_personName(payment.personId)),
                          subtitle: Text(
                            '${_bedLabel(payment.bedId)}'
                            '${_flatName(payment.flatId).isEmpty ? '' : ' · ${_flatName(payment.flatId)}'}'
                            '\nPaid ${formatMoneyShort(payment.amountPaid)} of '
                            '${formatMoneyShort(payment.amountDue)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: StatusBadge(status: payment.status),
                              ),
                              PopupMenuButton<_PaymentAction>(
                                onSelected: (action) {
                                  switch (action) {
                                    case _PaymentAction.paid:
                                      setState(() {
                                        widget.store.upsertPayment(
                                          PaymentService.markPaid(payment),
                                        );
                                      });
                                    case _PaymentAction.partial:
                                      _markPartial(payment);
                                    case _PaymentAction.unpaid:
                                      setState(() {
                                        widget.store.upsertPayment(
                                          PaymentService.markUnpaid(payment),
                                        );
                                      });
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: _PaymentAction.paid,
                                    child: Text('Mark paid'),
                                  ),
                                  PopupMenuItem(
                                    value: _PaymentAction.partial,
                                    child: Text('Mark partial…'),
                                  ),
                                  PopupMenuItem(
                                    value: _PaymentAction.unpaid,
                                    child: Text('Mark unpaid'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () => _markPartial(payment),
                          onLongPress: () => _markPartial(payment),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

enum _PaymentAction { paid, partial, unpaid }

class _PaymentForm extends StatefulWidget {
  const _PaymentForm({required this.store, required this.month});

  final JsonStore store;
  final String month;

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  final _formKey = GlobalKey<FormState>();
  Person? _person;
  late String _month;
  late final TextEditingController _amountDue;
  late final TextEditingController _amountPaid;

  @override
  void initState() {
    super.initState();
    _month = widget.month;
    _amountDue = TextEditingController();
    _amountPaid = TextEditingController();
  }

  @override
  void dispose() {
    _amountDue.dispose();
    _amountPaid.dispose();
    super.dispose();
  }

  void _selectPerson(Person? person) {
    setState(() {
      _person = person;
      final bed = widget.store.beds
          .where((b) => b.id == person?.bedId)
          .firstOrNull;
      _amountDue.text = bed == null ? '' : bed.monthlyRent.toStringAsFixed(0);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final due = double.tryParse(_amountDue.text.trim()) ?? 0;
    final paid = double.tryParse(_amountPaid.text.trim()) ?? 0;
    final person = _person!;
    final bedId = person.bedId!;
    final flatId = widget.store.beds.where((b) => b.id == bedId).first.flatId;

    Navigator.of(context).pop(
      Payment(
        id: newId(),
        personId: person.id,
        bedId: bedId,
        flatId: flatId,
        month: _month,
        amountDue: due,
        amountPaid: paid.clamp(0, due),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final eligiblePeople = widget.store.people.where((p) => p.hasBed).toList();
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
            Text('Add payment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<Person>(
              initialValue: _person,
              decoration: const InputDecoration(
                labelText: 'Tenant',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final person in eligiblePeople)
                  DropdownMenuItem(value: person, child: Text(person.name)),
              ],
              onChanged: _selectPerson,
              validator: (_) => _person == null ? 'Select a tenant' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _month,
              decoration: const InputDecoration(
                labelText: 'Month',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var i = 0; i < 12; i++)
                  DropdownMenuItem(
                    value: monthKey(DateTime(2026, 1 + i, 1)),
                    child: Text(monthKey(DateTime(2026, 1 + i, 1))),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _month = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountDue,
              decoration: const InputDecoration(
                labelText: 'Amount due',
                prefixText: 'Rs. ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final parsed = double.tryParse(v?.trim() ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountPaid,
              decoration: const InputDecoration(
                labelText: 'Amount paid (optional)',
                prefixText: 'Rs. ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Add')),
          ],
        ),
      ),
    );
  }
}
