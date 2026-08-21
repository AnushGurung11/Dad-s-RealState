import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/person.dart';
import '../services/rent_payment_service.dart';
import '../services/store_scope.dart';
import '../services/tenure_service.dart';
import '../utils/format.dart';
import '../widgets/grouped_tenant_list.dart';

/// Tenant Rent Payment: searchable, flat-grouped list of active tenants.
/// Selecting one opens the payment form; saving writes a rent Payment to the
/// ledger (balances recalculate on read).
class TenantRentPaymentScreen extends StatefulWidget {
  const TenantRentPaymentScreen({super.key});

  @override
  State<TenantRentPaymentScreen> createState() =>
      _TenantRentPaymentScreenState();
}

class _TenantRentPaymentScreenState extends State<TenantRentPaymentScreen> {
  String _query = '';

  void _refresh() => setState(() {});

  Future<void> _openPayDialog(Person person) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _RentPayDialog(person: person),
    );
    if (amount == null || !mounted) return;

    try {
      RentPaymentService(StoreScope.of(context))
          .recordRent(person: person, amountPaid: amount);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Rent payment recorded')));
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
    final store = StoreScope.of(context);
    final needle = _query.trim().toLowerCase();
    final people = RentPaymentService(store)
        .payablePeople()
        .where((p) => needle.isEmpty ||
            p.name.toLowerCase().contains(needle))
        .toList();
    final bedIds = people.map((p) => p.bedId).whereType<String>().toSet();
    final beds =
        store.beds.where((b) => bedIds.contains(b.id)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const Key('tenant_payment_search_field'),
          decoration: const InputDecoration(
            hintText: 'Search tenants',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        if (store.people.isEmpty || RentPaymentService(store).payablePeople().isEmpty)
          Text(
            'No active tenants.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else if (people.isEmpty)
          Text(
            'No tenants match "$_query".',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else
          GroupedTenantList(
            beds: beds,
            onPersonTap: _openPayDialog,
          ),
      ],
    );
  }
}

/// Rent form. Deliberately pre-fills NOTHING about the amount — the landlord
/// types what was actually collected.
class _RentPayDialog extends StatefulWidget {
  const _RentPayDialog({required this.person});

  final Person person;

  @override
  State<_RentPayDialog> createState() => _RentPayDialogState();
}

class _RentPayDialogState extends State<_RentPayDialog> {
  final _amountController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? get _amount =>
      double.tryParse(_amountController.text.trim().replaceAll(',', ''));

  String _dateText(DateTime date) => '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime(_date.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

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
      content: Column(
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
              labelText: 'Amount paid (AED)',
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
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text('Paid date: ${_dateText(_date)}'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('record_rent_payment'),
          onPressed: (_amount == null || _amount! <= 0)
              ? null
              : () => Navigator.pop(context, _amount),
          child: const Text('Record payment'),
        ),
      ],
    );
  }
}
