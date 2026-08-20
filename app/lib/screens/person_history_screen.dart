import 'package:flutter/material.dart';

import '../config.dart';
import '../models/payment.dart';
import '../models/person.dart';
import '../services/json_store.dart';
import '../services/tenure_service.dart';
import '../utils/format.dart';
import '../utils/ids.dart';
import '../widgets/confirm_delete_dialog.dart';

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

  Future<void> _openEditPerson() async {
    final result = await showModalBottomSheet<Person>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PersonForm(existing: widget.person),
    );
    if (result == null) return;
    setState(() {
      widget.store.upsertPerson(result);
    });
  }

  Future<void> _deletePerson() async {
    final bed = widget.store.beds.where((b) => b.id == widget.person.bedId);
    final detail = bed.isEmpty
        ? '${widget.person.name} has no bed assigned. Their payment history will be kept. Delete?'
        : '${widget.person.name} is assigned to ${bed.first.label}. They will be unassigned and their payment history kept. Delete?';
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete ${widget.person.name}?',
      detail: detail,
    );
    if (!confirmed) return;
    widget.store.deletePerson(widget.person.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${widget.person.name}')),
    );
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

  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: bold
                  ? Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold)
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final payments = widget.store.payments
        .where((p) => p.personId == person.id)
        .toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    final bed = widget.store.beds.where((b) => b.id == person.bedId).firstOrNull;
    double? balance;
    if (person.isActiveTenant && bed != null) {
      final rent = person.monthlyRent ?? bed.defaultMonthlyRent;
      balance = TenureService.remainingBalance(
        person,
        rent,
        widget.store.payments,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit tenant',
            onPressed: _openEditPerson,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete tenant',
            onPressed: _deletePerson,
          ),
        ],
      ),
      floatingActionButton: person.hasBed
          ? FloatingActionButton.extended(
              heroTag: 'person-history-fab',
              onPressed: _openAddPayment,
              icon: const Icon(Icons.add),
              label: const Text('Add payment'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.contact,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (person.workplaceOrInfo != null)
                    Text(
                      person.workplaceOrInfo!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const Divider(height: 20),
                  if (person.monthlyRent != null)
                    _row(
                      context,
                      'Monthly rent',
                      formatMoneyShort(person.monthlyRent!),
                    ),
                  if (person.depositAmount != null)
                    _row(context, 'Deposit', formatMoneyShort(person.depositAmount!)),
                  if (balance != null)
                    _row(context, 'Balance', formatMoneySigned(balance),
                        bold: true),
                  if (person.joinDate != null)
                    _row(
                      context,
                      'Joined',
                      '${person.joinDate!.day}/${person.joinDate!.month}/${person.joinDate!.year}',
                    ),
                  if (person.vacatedDate != null)
                    _row(
                      context,
                      'Left',
                      '${person.vacatedDate!.day}/${person.vacatedDate!.month}/${person.vacatedDate!.year}',
                    ),
                  if (person.others != null) ...[
                    const Divider(height: 20),
                    Text(
                      person.others!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No payment history for ${person.name} yet.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          else
            ...payments.map(
              (payment) => Card(
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
                            Text(
                              'Paid: ${formatMoneyShort(payment.amountPaid)}',
                            ),
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
              ),
            ),
        ],
      ),
    );
  }

  static String _typeLabel(PaymentType type) =>
      type == PaymentType.deposit ? 'Deposit' : 'Rent';
}

class _PersonForm extends StatefulWidget {
  const _PersonForm({required this.existing});

  final Person existing;

  @override
  State<_PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<_PersonForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _workplace;
  late final TextEditingController _monthlyRent;
  late final TextEditingController _others;
  DateTime? _vacatedDate;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing.name);
    _contact = TextEditingController(text: widget.existing.contact);
    _workplace = TextEditingController(
      text: widget.existing.workplaceOrInfo ?? '',
    );
    _monthlyRent = TextEditingController(
      text: widget.existing.monthlyRent == null
          ? ''
          : widget.existing.monthlyRent!.toStringAsFixed(0),
    );
    _others = TextEditingController(text: widget.existing.others ?? '');
    _vacatedDate = widget.existing.vacatedDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _workplace.dispose();
    _monthlyRent.dispose();
    _others.dispose();
    super.dispose();
  }

  Future<void> _pickVacatedDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _vacatedDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked == null) return;
    setState(() => _vacatedDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final monthlyRent = double.tryParse(_monthlyRent.text.trim());
    Navigator.of(context).pop(
      widget.existing.copyWith(
        name: _name.text.trim(),
        contact: _contact.text.trim(),
        workplaceOrInfo: _workplace.text.trim().isEmpty
            ? null
            : _workplace.text.trim(),
        monthlyRent: monthlyRent,
        others: _others.text.trim().isEmpty ? null : _others.text.trim(),
        vacatedDate: _vacatedDate,
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit tenant',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contact,
                decoration: const InputDecoration(
                  labelText: 'Contact',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Contact is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _workplace,
                decoration: const InputDecoration(
                  labelText: 'Workplace / info (optional)',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _monthlyRent,
                decoration: const InputDecoration(
                  labelText: 'Monthly rent',
                  prefixText: '${AppConfig.currencySymbol} ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _others,
                decoration: const InputDecoration(
                  labelText: 'Others',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              if (widget.existing.hasBed) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickVacatedDate,
                  icon: const Icon(Icons.event_available),
                  label: Text(
                    _vacatedDate == null
                        ? 'Vacated date'
                        : 'Left: ${_vacatedDate!.day}/${_vacatedDate!.month}/${_vacatedDate!.year}',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    final rent = widget.person.monthlyRent ?? bed?.defaultMonthlyRent;
    _amountDue = TextEditingController(
      text: rent == null ? '' : rent.toStringAsFixed(0),
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
            Text(
              'Add rent payment',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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