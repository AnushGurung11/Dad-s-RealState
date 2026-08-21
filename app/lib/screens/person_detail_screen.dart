import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/payment.dart';
import '../services/renewal_service.dart';
import '../services/store_scope.dart';
import '../services/tenure_service.dart';
import '../utils/format.dart';

/// Read-only tenant summary: tenure fields, current balance and payment
/// history. Money is never entered here — payments happen on the Payments
/// page (single entry point), so this screen has no entry controls.
class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen({super.key, required this.personId});

  final String personId;

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  void _refresh() => setState(() {});

  Future<void> _openRenewDialog() async {
    final months = await showDialog<int>(
      context: context,
      builder: (dialogContext) => const _RenewDialog(),
    );
    if (months == null || !mounted) return;
    try {
      RenewalService(StoreScope.of(context)).renew(
        personId: widget.personId,
        additionalMonths: months,
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Stay extended by $months month(s)')));
    } on RenewalException catch (error) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
    _refresh();
  }

  String? _dateText(DateTime? date) => date == null
      ? null
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final person =
        store.people.where((p) => p.id == widget.personId).firstOrNull;
    if (person == null) {
      return const Scaffold(body: Center(child: Text('Tenant not found.')));
    }

    final rent = person.monthlyRent ?? 0;
    final balance = TenureService.remainingBalance(person, rent, store.payments);
    final payments = store.payments
        .where((p) => p.personId == person.id)
        .toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (person.archived)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Archived tenant'),
                subtitle: Text(
                  'Archived on ${_dateText(person.archivedAt) ?? '—'}. '
                  'Their history is kept.',
                ),
              ),
            ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(label: 'Monthly rent', value: formatMoneyShort(rent)),
                  _Field(
                      label: 'Deposit',
                      value: formatMoneyShort(person.depositAmount ?? 0)),
                  _Field(label: 'Join date', value: _dateText(person.joinDate)),
                  _Field(
                      label: 'Vacated date',
                      value: _dateText(person.vacatedDate)),
                  _Field(label: 'Notes', value: person.others),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Remaining balance',
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        formatMoneySigned(balance),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Archived tenants are done — no renew action for them.
          if (!person.archived)
            FilledButton.icon(
              onPressed: person.isActiveTenant ? _openRenewDialog : null,
              icon: const Icon(Icons.update),
              label: const Text('Renew stay'),
            ),
          if (!person.archived) const SizedBox(height: 24),
          Text('Payment history',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (payments.isEmpty)
            Text(
              'No payments recorded yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            ...payments.map((payment) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      payment.type == PaymentType.deposit
                          ? Icons.savings_outlined
                          : Icons.receipt_outlined,
                    ),
                    title: Text(payment.month),
                    subtitle: Text(
                        payment.type == PaymentType.deposit
                            ? 'Deposit'
                            : 'Rent'),
                    trailing: Text(formatMoneyShort(payment.amountPaid)),
                  ),
                )),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            (value == null || value!.isEmpty) ? '—' : value!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Small form asking how many months to add to the planned stay.
class _RenewDialog extends StatefulWidget {
  const _RenewDialog();

  @override
  State<_RenewDialog> createState() => _RenewDialogState();
}

class _RenewDialogState extends State<_RenewDialog> {
  final _controller = TextEditingController(text: '6');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _months {
    final value = int.tryParse(_controller.text.trim());
    return (value == null || value < 1) ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renew stay'),
      content: TextFormField(
        key: const Key('renew_months_field'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Additional months',
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _months == null ? null : () => Navigator.pop(context, _months),
          child: const Text('Extend'),
        ),
      ],
    );
  }
}
