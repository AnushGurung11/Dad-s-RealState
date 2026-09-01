// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/flat.dart';
import '../models/lease_cheque_record.dart';
import '../models/lease_cheque_setting.dart';
import '../services/flat_creation_service.dart';
import '../services/flat_lease_payment_service.dart';
import '../services/store_scope.dart';
import '../services/transaction_edit_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/duration_format.dart';

/// Payment methods available for cheque payments.
const List<String> kPaymentMethods = ['Card', 'Cash', 'Cheque', 'Online', 'Other'];

/// Cheque Flats: manage recurring lease cheque payments for flats.
/// Shows flats with cheque settings (due list) and allows adding cheque
/// details to flats that don't have them yet.
class ChequePaymentFlatScreen extends StatefulWidget {
  const ChequePaymentFlatScreen({super.key});

  @override
  State<ChequePaymentFlatScreen> createState() => _ChequePaymentFlatScreenState();
}

class _ChequePaymentFlatScreenState extends State<ChequePaymentFlatScreen> {
  String _dateText(DateTime date) => '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Opens the add cheque setting flow for a flat without cheque details.
  Future<void> _addChequeSetting() async {
    final store = StoreScope.of(context);
    final activeFlats = store.flats.where((f) => !f.archived).toList();
    final flatsWithCheque = store.leaseChequeSettings.map((s) => s.flatId).toSet();
    final availableFlats = activeFlats.where((f) => !flatsWithCheque.contains(f.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (availableFlats.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All active flats already have cheque details')),
      );
      return;
    }

    final selectedFlat = await showDialog<Flat>(
      context: context,
      builder: (_) => _FlatPickerDialog(flats: availableFlats),
    );
    if (selectedFlat == null || !mounted) return;

    final result = await showDialog<({String ownerName, double amount, int intervalMonths, DateTime nextDueDate})>(
      context: context,
      builder: (_) => _AddChequeSettingDialog(flat: selectedFlat),
    );
    if (result == null || !mounted) return;

    final service = FlatCreationService(store);
    service.addChequeSetting(
      flatId: selectedFlat.id,
      ownerName: result.ownerName,
      amount: result.amount,
      nextDueDate: result.nextDueDate,
      intervalMonths: result.intervalMonths,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Cheque details added for ${selectedFlat.name}')));
    setState(() {});
  }

  Future<void> _openPayDialog(LeaseChequeSetting setting, Flat flat) async {
    final result = await showDialog<({double amount, DateTime date, int months, DateTime? explicitNextDueDate, String? description, String? paymentMethod})>(
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

  Future<void> _deleteSetting(LeaseChequeSetting setting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete cheque setting?'),
        content: const Text('This will remove the recurring lease payment configuration for this flat. Existing payment records will not be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final store = StoreScope.of(context);
    store.deleteChequeSetting(setting.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Cheque setting deleted')));
    setState(() {});
  }

  Future<void> _viewPaymentHistory(LeaseChequeSetting setting, Flat flat) async {
    final store = StoreScope.of(context);
    final records = store.leaseChequeRecords
        .where((r) => r.flatId == setting.flatId)
        .toList()
      ..sort((a, b) => b.paidDate.compareTo(a.paidDate));

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChequePaymentHistoryScreen(
          flat: flat,
          setting: setting,
          records: records,
        ),
      ),
    );
    if (mounted) setState(() {});
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

    // Check if there are flats without cheque settings
    final flatsWithCheque = store.leaseChequeSettings.map((s) => s.flatId).toSet();
    final hasFlatsWithoutCheque = store.flats
        .where((f) => !f.archived && !flatsWithCheque.contains(f.id))
        .isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Add cheque setting button
        if (hasFlatsWithoutCheque)
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              key: const Key('add_cheque_setting'),
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Add cheque details to flat'),
              subtitle: const Text('Set up recurring lease payments for a flat'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _addChequeSetting,
            ),
          ),
        // Due list
        if (settings.isEmpty)
          const Center(child: Text('No flats with lease cheques yet.'))
        else ...[
          Text('Upcoming Payments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final setting in settings)
            _buildRow(context, setting, today, statusColors),
        ],
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
      child: InkWell(
        onTap: () => _viewPaymentHistory(setting, flat!),
        borderRadius: BorderRadius.circular(12),
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
              IconButton(
                key: ValueKey('delete-setting-${setting.id}'),
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Delete setting',
                onPressed: () => _deleteSetting(setting),
              ),
              FilledButton(
                key: ValueKey('pay-${setting.id}'),
                onPressed: () => _openPayDialog(setting, flat!),
                child: const Text('Pay'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picker dialog for selecting a flat without cheque settings.
class _FlatPickerDialog extends StatelessWidget {
  const _FlatPickerDialog({required this.flats});

  final List<Flat> flats;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select flat for cheque details'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: flats.length,
          itemBuilder: (context, index) {
            final flat = flats[index];
            return ListTile(
              key: ValueKey('pick-flat-${flat.id}'),
              leading: const Icon(Icons.apartment_outlined),
              title: Text(flat.name),
              subtitle: Text(flat.address, maxLines: 1),
              onTap: () => Navigator.pop(context, flat),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// Dialog for adding cheque setting details to a flat.
class _AddChequeSettingDialog extends StatefulWidget {
  const _AddChequeSettingDialog({required this.flat});

  final Flat flat;

  @override
  State<_AddChequeSettingDialog> createState() => _AddChequeSettingDialogState();
}

class _AddChequeSettingDialogState extends State<_AddChequeSettingDialog> {
  late final TextEditingController _ownerController;
  late final TextEditingController _amountController;
  late final TextEditingController _intervalController;
  int _dueDay = DateTime.now().day.clamp(1, 28);

  @override
  void initState() {
    super.initState();
    _ownerController = TextEditingController(text: widget.flat.contractPerson ?? '');
    _amountController = TextEditingController();
    _intervalController = TextEditingController(text: '2');
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _amountController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  DateTime _computeNextDueDate() {
    final now = DateTime.now();
    final interval = int.tryParse(_intervalController.text) ?? 2;
    final nextMonth = DateTime(now.year, now.month + interval, 1);
    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    return DateTime(nextMonth.year, nextMonth.month, _dueDay.clamp(1, lastDay));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add cheque details for ${widget.flat.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('cheque_owner_name'),
              controller: _ownerController,
              decoration: const InputDecoration(
                labelText: 'Owner name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('cheque_amount'),
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (AED)',
                border: OutlineInputBorder(),
                helperText: 'Default amount to pay each time',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*'))],
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('cheque_interval'),
              controller: _intervalController,
              decoration: const InputDecoration(
                labelText: 'Repeat after (months)',
                border: OutlineInputBorder(),
                helperText: 'Next payment will be after this many months',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('cheque_due_day'),
              value: _dueDay,
              decoration: const InputDecoration(
                labelText: 'Due day of month',
                border: OutlineInputBorder(),
                helperText: 'Day when payment is due (1–28)',
              ),
              items: List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
              onChanged: (v) => setState(() { if (v != null) _dueDay = v; }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          key: const Key('save_cheque_setting'),
          onPressed: () {
            final amount = double.tryParse(_amountController.text.trim().replaceAll(',', ''));
            final interval = int.tryParse(_intervalController.text.trim());
            if (amount == null || amount <= 0 || interval == null || interval < 1) return;
            Navigator.pop(context, (
              ownerName: _ownerController.text,
              amount: amount,
              intervalMonths: interval,
              nextDueDate: _computeNextDueDate(),
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Pay form: editable amount, paid date, months, payment method, description.
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
  int? _nextDueDay;
  String? _paymentMethod;

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record cheque payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Payment method
            DropdownButtonFormField<String>(
              key: const Key('payment_method_field'),
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment method',
                border: OutlineInputBorder(),
              ),
              items: kPaymentMethods
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _paymentMethod = v),
            ),
            const SizedBox(height: 12),
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
            DropdownButtonFormField<int>(
              key: const Key('next_payment_day_field'),
              value: _nextDueDay,
              decoration: const InputDecoration(
                labelText: 'Next payment day of month (optional)',
                border: OutlineInputBorder(),
                helperText: 'Day of month for next payment (1–28)',
              ),
              items: [const DropdownMenuItem<int>(value: null, child: Text('Auto (after months covered)'))]
                ..addAll(List.generate(28, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')))),
              onChanged: (v) => setState(() => _nextDueDay = v),
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
              : () {
                  DateTime? explicitNextDueDate;
                  if (_nextDueDay != null) {
                    final now = DateTime.now();
                    final nextMonth = DateTime(now.year, now.month + _months!, 1);
                    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
                    explicitNextDueDate = DateTime(nextMonth.year, nextMonth.month, _nextDueDay!.clamp(1, lastDay));
                  }
                  Navigator.pop(context, (
                    amount: _amount!,
                    date: _date,
                    months: _months!,
                    explicitNextDueDate: explicitNextDueDate,
                    description: _descController.text.isEmpty ? null : _descController.text,
                    paymentMethod: _paymentMethod,
                  ));
                },
          child: const Text('Record payment'),
        ),
      ],
    );
  }
}

/// Edit setting dialog.
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

/// Payment history screen for a specific flat's cheque payments.
class _ChequePaymentHistoryScreen extends StatefulWidget {
  const _ChequePaymentHistoryScreen({
    required this.flat,
    required this.setting,
    required this.records,
  });

  final Flat flat;
  final LeaseChequeSetting setting;
  final List<LeaseChequeRecord> records;

  @override
  State<_ChequePaymentHistoryScreen> createState() => _ChequePaymentHistoryScreenState();
}

class _ChequePaymentHistoryScreenState extends State<_ChequePaymentHistoryScreen> {
  String _dateText(DateTime date) => '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final records = store.leaseChequeRecords
        .where((r) => r.flatId == widget.flat.id)
        .toList()
      ..sort((a, b) => b.paidDate.compareTo(a.paidDate));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.flat.name} Payments'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Setting info card
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.flat.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Amount: ${formatMoneyShort(widget.setting.amount)}'),
                  Text('Frequency: Every ${widget.setting.intervalMonths} month(s)'),
                  Text('Next due: ${_dateText(widget.setting.nextDueDate)}'),
                ],
              ),
            ),
          ),
          Text('Payment History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (records.isEmpty)
            const Text('No payments yet.')
          else
            for (final record in records) _buildRecordRow(record),
        ],
      ),
    );
  }

  Widget _buildRecordRow(LeaseChequeRecord record) {
    final store = StoreScope.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.receipt_long),
        title: Text(formatMoneyShort(record.amount)),
        subtitle: Text(
          'Paid ${_dateText(record.paidDate)} · Due ${_dateText(record.dueDate)}'
          '${record.paymentMethod != null ? ' · ${record.paymentMethod}' : ''}'
          '${record.description != null ? ' · ${record.description}' : ''}',
        ),
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
                    title: const Text('Edit payment record'),
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
                      _refresh();
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
                    _refresh();
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
