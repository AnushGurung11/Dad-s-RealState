import 'package:flutter/material.dart';

import '../config.dart';
import '../models/payment.dart';
import '../models/person.dart';
import '../services/json_store.dart';
import '../utils/format.dart';
import '../utils/ids.dart';

class PersonHistoryScreen extends StatefulWidget {
  const PersonHistoryScreen({
    super.key,
    required this.store,
    required this.person,
  });

  final JsonStore store;
  final Person person;

  @override
  State<PersonHistoryScreen> createState() => _PersonHistoryScreenState();
}

class _PersonHistoryScreenState extends State<PersonHistoryScreen> {
  String _bedLabel(String bedId) {
    final match = widget.store.beds.where((b) => b.id == bedId);
    return match.isEmpty ? 'Unknown bed' : match.first.label;
  }

  Future<void> _openAddPayment() async {
    final result = await showModalBottomSheet<Payment>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentForm(store: widget.store, person: widget.person),
    );
    if (result == null) return;
    setState(() {
      widget.store.upsertPayment(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final payments = widget.store.payments
        .where((p) => p.personId == widget.person.id)
        .toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    return Scaffold(
      appBar: AppBar(title: Text(widget.person.name)),
      floatingActionButton: widget.person.hasBed
          ? FloatingActionButton.extended(
              heroTag: 'person-history-fab',
              onPressed: _openAddPayment,
              icon: const Icon(Icons.add),
              label: const Text('Add payment'),
            )
          : null,
      body: payments.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No payment history for ${widget.person.name} yet.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: payments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final payment = payments[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                    title: Text('${payment.month} · ${_typeLabel(payment.type)}'),
                    subtitle: Text(
                      '${_bedLabel(payment.bedId)} · '
                      'Paid ${formatMoneyShort(payment.amountPaid)} of '
                      '${formatMoneyShort(payment.amountDue)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            '${_typeLabel(payment.type)} · ${payment.month}',
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Due: ${formatMoneyShort(payment.amountDue)}'),
                              Text('Paid: ${formatMoneyShort(payment.amountPaid)}'),
                              Text(
                                'Outstanding: ${formatMoneyShort(payment.amountDue - payment.amountPaid)}',
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  static String _typeLabel(PaymentType type) =>
      type == PaymentType.deposit ? 'Deposit' : 'Rent';
}

class _PaymentForm extends StatefulWidget {
  const _PaymentForm({required this.store, required this.person});

  final JsonStore store;
  final Person person;

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  final _formKey = GlobalKey<FormState>();
  late String _month;
  late final TextEditingController _amountDue;
  late final TextEditingController _amountPaid;

  @override
  void initState() {
    super.initState();
    _month = monthKey(DateTime.now());
    final bed = widget.store.beds
        .where((b) => b.id == widget.person.bedId)
        .firstOrNull;
    _amountDue = TextEditingController(
      text: bed == null ? '' : bed.monthlyRent.toStringAsFixed(0),
    );
    _amountPaid = TextEditingController();
  }

  @override
  void dispose() {
    _amountDue.dispose();
    _amountPaid.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final due = double.tryParse(_amountDue.text.trim()) ?? 0;
    final paid = double.tryParse(_amountPaid.text.trim()) ?? 0;
    final person = widget.person;
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
        type: PaymentType.rent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final now = DateTime.now();
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
            Text('Add rent payment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _month,
              decoration: const InputDecoration(
                labelText: 'Month',
                border: OutlineInputBorder(),
              ),
              items: [
                for (var i = -6; i <= 6; i++)
                  DropdownMenuItem(
                    value: monthKey(DateTime(now.year, now.month + i, 1)),
                    child: Text(monthKey(DateTime(now.year, now.month + i, 1))),
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
                prefixText: '${AppConfig.currencySymbol} ',
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
                prefixText: '${AppConfig.currencySymbol} ',
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