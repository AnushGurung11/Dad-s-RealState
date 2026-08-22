import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/lease_cheque_setting.dart';
import '../services/flat_lease_payment_service.dart';
import '../services/store_scope.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Flat Lease Payment: every flat's cheque due list sorted by due date,
/// with a pay flow that records the payment and advances the schedule.
/// (Reminders were removed — this page IS the "what's coming up" view.)
class FlatLeasePaymentScreen extends StatefulWidget {
  const FlatLeasePaymentScreen({super.key});

  @override
  State<FlatLeasePaymentScreen> createState() =>
      _FlatLeasePaymentScreenState();
}

class _FlatLeasePaymentScreenState extends State<FlatLeasePaymentScreen> {
  int _daysRemaining(DateTime due, DateTime today) {
    final dueDate = DateTime(due.year, due.month, due.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    return dueDate.difference(todayDate).inDays;
  }

  String _dateText(DateTime date) => '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _openPayDialog(LeaseChequeSetting setting) async {
    final result = await showDialog<({double amount, DateTime date})>(
      context: context,
      builder: (_) => _LeasePayDialog(initialAmount: setting.amount),
    );
    if (result == null || !mounted) return;

    try {
      final service =
          FlatLeasePaymentService(StoreScope.of(context));
      service.pay(
        setting: setting,
        amount: result.amount,
        paidDate: result.date,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Lease payment recorded')));
      setState(() {}); // Row refreshes with the advanced due date.
    } on LeasePaymentException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final settings = FlatLeasePaymentService(store).dueList();
    final today = DateTime.now();
    final statusColors = Theme.of(context).extension<AppStatusColors>()!;

    if (settings.isEmpty) {
      return const Center(child: Text('No flats with lease cheques yet.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final setting in settings)
          _buildRow(context, setting, today, statusColors.danger),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    LeaseChequeSetting setting,
    DateTime today,
    Color dangerColor,
  ) {
    final store = StoreScope.of(context);
    final flat = store.flats
        .where((f) => f.id == setting.flatId)
        .firstOrNull;
    final days = _daysRemaining(setting.nextDueDate, today);
    final overdue = days < 0;
    final daysText = overdue
        ? '${-days} ${days == -1 ? 'day' : 'days'} overdue'
        : days == 0
            ? 'Due today'
            : 'in $days ${days == 1 ? 'day' : 'days'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Icon(Icons.receipt_long_outlined,
                color: overdue ? dangerColor : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(flat?.name ?? 'Unknown flat',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${formatMoneyShort(setting.amount)} · '
                    'Due ${_dateText(setting.nextDueDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    daysText,
                    style: TextStyle(
                      color: overdue ? dangerColor : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: ValueKey('pay-${setting.id}'),
              onPressed: () => _openPayDialog(setting),
              child: const Text('Pay'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pay form: editable amount (pre-filled from the setting) and paid date.
class _LeasePayDialog extends StatefulWidget {
  const _LeasePayDialog({required this.initialAmount});

  final double initialAmount;

  @override
  State<_LeasePayDialog> createState() => _LeasePayDialogState();
}

class _LeasePayDialogState extends State<_LeasePayDialog> {
  late final TextEditingController _amountController;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: formatMoney(widget.initialAmount));
  }

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
    return AlertDialog(
      title: const Text('Record lease payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            key: const Key('lease_amount_field'),
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount (AED)',
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
          key: const Key('record_lease_payment'),
          onPressed: (_amount == null || _amount! <= 0)
              ? null
              : () => Navigator.pop(
                  context, (amount: _amount!, date: _date)),
          child: const Text('Record payment'),
        ),
      ],
    );
  }
}
