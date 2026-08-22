import 'package:flutter/material.dart';

import '../models/lease_termination_record.dart';
import '../models/person.dart';
import '../services/store_scope.dart';
import '../services/termination_service.dart';
import '../utils/format.dart';

/// "End tenure early" flow: pick a reason ("Other" requires a note), review
/// the calculated breakdown — total paid across prepaid months, days stayed
/// this final month, earned amount and the REFUND — then confirm.
///
/// The breakdown is rendered straight from [TerminationService.calculate];
/// no ad hoc math lives in the widget.
class TerminationFlowScreen extends StatefulWidget {
  const TerminationFlowScreen({super.key, required this.personId});

  final String personId;

  @override
  State<TerminationFlowScreen> createState() => _TerminationFlowScreenState();
}

class _TerminationFlowScreenState extends State<TerminationFlowScreen> {
  TerminationReason _reason = TerminationReason.financial;
  final _noteController = TextEditingController();
  DateTime _terminationDate = DateTime.now();
  bool _confirmed = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _noteValid =>
      _reason != TerminationReason.other ||
      _noteController.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _terminationDate,
      firstDate: DateTime(_terminationDate.year - 5),
      lastDate: DateTime(_terminationDate.year + 5),
    );
    if (picked != null) setState(() => _terminationDate = picked);
  }

  String _dateText(DateTime date) => '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _submit(Person person, TerminationCalculation calc) async {
    try {
      final record = TerminationService.terminate(
        StoreScope.of(context),
        person: person,
        calculation: calc,
        reason: _reason,
        reasonNote: _noteController.text.trim(),
        terminationDate: _terminationDate,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(record.refundAmount > 0
                ? 'Tenure ended. Refund of ${formatMoneyShort(record.refundAmount)} due.'
                : 'Tenure ended. No refund due.')));
      Navigator.pop(context);
    } on TerminationException catch (error) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final person =
        store.people.where((p) => p.id == widget.personId).firstOrNull;
    if (person == null) {
      return const Scaffold(body: Center(child: Text('Tenant not found.')));
    }

    final calc =
        TerminationService.calculate(person, store.payments, _terminationDate);

    return Scaffold(
      appBar: AppBar(title: Text('End tenure early — ${person.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<TerminationReason>(
            key: const Key('termination_reason_picker'),
            initialValue: _reason,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
            items: TerminationReason.values
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.label),
                    ))
                .toList(),
            onChanged: (value) =>
                setState(() => _reason = value ?? TerminationReason.financial),
          ),
          if (_reason == TerminationReason.other) ...[
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('termination_note_field'),
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'What happened? (required)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text('Termination date: ${_dateText(_terminationDate)}'),
          ),
          const SizedBox(height: 20),
          Card(
            key: const Key('termination_breakdown'),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Breakdown',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _Row(
                      label: 'Total paid across prepaid months',
                      value: formatMoneyShort(calc.totalPaidAcrossPrepaidMonths)),
                  _Row(
                      label: 'Days stayed in final month',
                      value: '${calc.daysStayedFinalMonth}'),
                  _Row(
                      label: 'Earned for days stayed',
                      value: formatMoneyShort(calc.earnedFinalMonth)),
                  _Row(
                      label: 'Unused future months',
                      value: formatMoneyShort(calc.refundFutureMonths)),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Refund due',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        formatMoneyShort(calc.refundAmount),
                        key: const Key('refund_amount'),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('confirm_termination'),
            onPressed: !_noteValid || !_confirmed
                ? null
                : () => _submit(person, calc),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Confirm end of tenure'),
          ),
          if (!_confirmed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CheckboxListTile(
                key: const Key('termination_ack'),
                value: _confirmed,
                onChanged: (value) =>
                    setState(() => _confirmed = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                    'I understand the refund above will be returned to the '
                    'tenant and their records stay unchanged.'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
