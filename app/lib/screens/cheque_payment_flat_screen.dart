// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/flat.dart';
import '../models/lease_cheque_record.dart';
import '../models/lease_cheque_setting.dart';
import '../services/flat_lease_payment_service.dart';
import '../services/store_scope.dart';
import '../services/transaction_edit_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/duration_format.dart';

/// Cheque Payment (Flat): every flat's cheque due list sorted by due date,
/// with a pay flow that records the payment and advances the schedule.
/// Past records are shown below with inline edit/delete via transaction_edit_service.
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
    final result = await showDialog<({double amount, DateTime date, int months, DateTime? explicitNextDueDate, String? description})>(
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
        explicitNextDueDate: result.explicitNextDueDate,
        description: result.description,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Cheque payment recorded')));
      setState(() {});
    } on LeasePaymentException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openEditSettingDialog(LeaseChequeSetting setting) async {
    final result = await showDialog<({double amount, DateTime nextDueDate, int intervalMonths})>(
      context: context,
      builder: (_) => _EditSettingDialog(setting: setting),
    );
    if (result == null || !mounted) return;
    final service = FlatLeasePaymentService(StoreScope.of(context));
    service.updateSetting(
      setting,
      amount: result.amount,
      nextDueDate: result.nextDueDate,
      intervalMonths: result.intervalMonths,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Lease setting updated')));
    setState(() {});
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

    final activeFlatIds = store.flats.where((f) => !f.archived).map((f) => f.id).toSet();
    final settings = allSettings.where((s) => activeFlatIds.contains(s.flatId)).toList();

    final records = store.leaseChequeRecords.toList()
      ..sort((a, b) => b.paidDate.compareTo(a.paidDate));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (settings.isEmpty)
          const Center(child: Text('No flats with lease cheques yet.'))
        else
          for (final setting in settings) _buildRow(context, setting, today, statusColors),
        const SizedBox(height: 24),
        Text('Past Payments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (records.isEmpty)
          const Text('No past payments yet.')
        else
          for (final record in records) _buildRecordRow(context, record),
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
    final flat = store.flats.where((f) => f.id == setting.flatId).firstOrNull;

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
                  Text(flat?.name ?? 'Unknown flat', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${formatMoneyShort(setting.amount)} · Due ${_dateText(setting.nextDueDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    daysText,
                    style: TextStyle(color: dueColor, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: ValueKey('edit-setting-${setting.id}'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit setting',
              onPressed: () => _openEditSettingDialog(setting),
            ),
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

  Widget _buildRecordRow(BuildContext context, LeaseChequeRecord record) {
    final store = StoreScope.of(context);
    final flat = store.flats.where((f) => f.id == record.flatId).firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.receipt_long),
        title: Text('${formatMoneyShort(record.amount)} · ${flat?.name ?? record.flatId}'),
        subtitle: Text('Paid ${_dateText(record.paidDate)} · Due ${_dateText(record.dueDate)}${record.description != null ? ' · ${record.description}' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: ValueKey('edit-record-${record.id}'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () async {
                final controller = TextEditingController(text: record.amount.toString());
                final descController = TextEditingController(text: record.description ?? '');
                final result = await showDialog<({double amount, String? description})>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Edit lease record'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: controller,
                          decoration: const InputDecoration(labelText: 'Amount (AED)', border: OutlineInputBorder()),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descController,
                          decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, (amount: double.tryParse(controller.text) ?? record.amount, description: descController.text.isEmpty ? null : descController.text)), child: const Text('Save')),
                    ],
                  ),
                );
                if (result != null && mounted) {
                  try {
                    await TransactionEditService(store).editLeaseChequeRecord(
                      record.id,
                      amount: result.amount,
                      description: result.description,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record updated')));
                      setState(() {});
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
            ),
            IconButton(
              key: ValueKey('delete-record-${record.id}'),
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete record?'),
                    content: const Text('This will be audited.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (confirmed != true) return;
                try {
                  await TransactionEditService(store).deleteLeaseChequeRecord(record.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record deleted')));
                    setState(() {});
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Pay form: editable amount, paid date, months, next payment date optional, description.
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
  final TextEditingController _descController = TextEditingController();
  DateTime _date = DateTime.now();
  DateTime? _explicitNextDueDate;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: formatMoney(widget.initialAmount));
    _monthsController = TextEditingController(text: widget.defaultMonths.toString());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _monthsController.dispose();
    _descController.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountController.text.trim().replaceAll(',', ''));

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

  Future<void> _pickNextDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _explicitNextDueDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _explicitNextDueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record cheque payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('lease_amount_field'),
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount (AED)', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*'))],
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('next_payment_date_field'),
              onPressed: _pickNextDueDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(_explicitNextDueDate == null ? 'Next payment date (optional)' : 'Next payment date: ${_dateText(_explicitNextDueDate!)}'),
            ),
            if (_explicitNextDueDate != null)
              TextButton(
                onPressed: () => setState(() => _explicitNextDueDate = null),
                child: const Text('Clear'),
              ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('cheque_description_field'),
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('record_lease_payment'),
          onPressed: (_amount == null || _amount! <= 0 || _months == null)
              ? null
              : () => Navigator.pop(context, (amount: _amount!, date: _date, months: _months!, explicitNextDueDate: _explicitNextDueDate, description: _descController.text.isEmpty ? null : _descController.text)),
          child: const Text('Record payment'),
        ),
      ],
    );
  }
}

class _EditSettingDialog extends StatefulWidget {
  const _EditSettingDialog({required this.setting});
  final LeaseChequeSetting setting;

  @override
  State<_EditSettingDialog> createState() => _EditSettingDialogState();
}

class _EditSettingDialogState extends State<_EditSettingDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _intervalController;
  late DateTime _nextDueDate;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.setting.amount.toString());
    _intervalController = TextEditingController(text: widget.setting.intervalMonths.toString());
    _nextDueDate = widget.setting.nextDueDate;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  String _dateText(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _nextDueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit lease setting'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            key: const Key('edit_setting_amount'),
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Amount (AED)', border: OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('edit_setting_due_date'),
            onPressed: _pickDueDate,
            icon: const Icon(Icons.event_outlined),
            label: Text('Next due: ${_dateText(_nextDueDate)}'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('edit_setting_interval'),
            controller: _intervalController,
            decoration: const InputDecoration(labelText: 'Frequency (months)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final amt = double.tryParse(_amountController.text.trim());
            final interval = int.tryParse(_intervalController.text.trim());
            Navigator.pop(context, (amount: amt ?? widget.setting.amount, nextDueDate: _nextDueDate, intervalMonths: interval ?? widget.setting.intervalMonths));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
