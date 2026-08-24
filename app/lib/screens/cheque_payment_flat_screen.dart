import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/flat.dart';
import '../models/lease_cheque_setting.dart';
import '../services/flat_lease_payment_service.dart';
import '../services/store_scope.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/duration_format.dart';

/// Cheque Payment (Flat): every flat's cheque due list sorted by due date,
/// with a pay flow that records the payment and advances the schedule.
/// (Reminders were removed — this page IS the "what's coming up" view.)
class ChequePaymentFlatScreen extends StatefulWidget {
  const ChequePaymentFlatScreen({super.key});

  @override
  State<ChequePaymentFlatScreen> createState() => _ChequePaymentFlatScreenState();
}

class _ChequePaymentFlatScreenState extends State<ChequePaymentFlatScreen> {
  String _dateText(DateTime date) => '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> _openPayDialog(LeaseChequeSetting setting, Flat flat) async {
    final result = await showDialog<({double amount, DateTime date, int months})>(
      context: context,
      builder: (_) => _ChequePayDialog(
        initialAmount: setting.amount,
        defaultMonths: setting.intervalMonths,
      ),
    );
    if (result == null || !mounted) return;

    try {
      final service = FlatLeasePaymentService(StoreScope.of(context));
      service.pay(
        setting: setting,
        amount: result.amount,
        paidDate: result.date,
        monthsCovered: result.months,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Cheque payment recorded')));
      setState(() {}); // Row refreshes with the advanced due date.
    } on LeasePaymentException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Color _dueDateColor(AppStatusColors statusColors, int totalDays) {
    if (totalDays < 0) return statusColors.danger;
    if (totalDays <= 7) return statusColors.danger;
    if (totalDays <= 30) return statusColors.warning;
    return statusColors.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final service = FlatLeasePaymentService(store);
    final allSettings = service.dueList();
    final today = DateTime.now();
    final statusColors = Theme.of(context).extension<AppStatusColors>()!;

    // Filter out archived flats
    final activeFlatIds = store.flats
        .where((f) => !f.archived)
        .map((f) => f.id)
        .toSet();
    final settings = allSettings
        .where((s) => activeFlatIds.contains(s.flatId))
        .toList();

    if (settings.isEmpty) {
      return const Center(child: Text('No flats with lease cheques yet.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final setting in settings)
          _buildRow(context, setting, today, statusColors),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    LeaseChequeSetting setting,
    DateTime today,
    AppStatusColors statusColors,
  ) {
    final store = StoreScope.of(context);
    final flat = store.flats
        .where((f) => f.id == setting.flatId)
        .firstOrNull;
    
    // Calculate days remaining
    final dueDate = DateTime(setting.nextDueDate.year, setting.nextDueDate.month, setting.nextDueDate.day);
    final todayDate = DateTime(today.year, today.month, today.day);
    final totalDays = dueDate.difference(todayDate).inDays;
    
    final daysText = formatRemaining(totalDays);
    final dueColor = _dueDateColor(statusColors, totalDays);
    final isOverdue = totalDays < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Icon(Icons.receipt_long_outlined, color: isOverdue ? statusColors.danger : null),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(flat?.name ?? 'Unknown flat',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${formatMoneyShort(setting.amount)} · Due ${_dateText(setting.nextDueDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    daysText,
                    style: TextStyle(
                      color: dueColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: ValueKey('pay-${setting.id}'),
              onPressed: () => _openPayDialog(setting, flat!),
              child: const Text('Pay'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pay form: editable amount (pre-filled from the setting), paid date,
/// and custom months this payment covers.
class _ChequePayDialog extends StatefulWidget {
  const _ChequePayDialog({
    required this.initialAmount,
    required this.defaultMonths,
  });

  final double initialAmount;
  final int defaultMonths;

  @override
  State<_ChequePayDialog> createState() => _ChequePayDialogState();
}

class _ChequePayDialogState extends State<_ChequePayDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _monthsController;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amountController =
        TextEditingController(text: formatMoney(widget.initialAmount));
    _monthsController = TextEditingController(text: widget.defaultMonths.toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  double? get _amount =>
      double.tryParse(_amountController.text.trim().replaceAll(',', ''));
  
  int? get _months {
    final value = int.tryParse(_monthsController.text.trim());
    return (value != null && value > 0) ? value : null;
  }

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
      title: const Text('Record cheque payment'),
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
          TextFormField(
            key: const Key('months_covered_field'),
            controller: _monthsController,
            decoration: const InputDecoration(
              labelText: 'Months this payment covers',
              border: OutlineInputBorder(),
              helperText: 'Enter the number of months this payment covers',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
          onPressed: (_amount == null || _amount! <= 0 || _months == null)
              ? null
              : () => Navigator.pop(
                  context, (amount: _amount!, date: _date, months: _months!)),
          child: const Text('Record payment'),
        ),
      ],
    );
  }
}