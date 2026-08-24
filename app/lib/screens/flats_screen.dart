import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../models/bed.dart';
import '../models/flat.dart';
import '../models/lease_cheque_record.dart';
import '../navigation/routes.dart';
import '../services/bed_capacity_service.dart';
import '../services/flat_creation_service.dart';
import '../services/flat_deletion_service.dart';
import '../services/store_scope.dart';
import '../utils/format.dart';
import '../utils/ids.dart';

/// Flats grid — the brief view of ACTIVE (non-archived) flats. Each card
/// shows the flat name and its occupancy count; tapping opens the detail
/// screen. Edit and Delete live here on the main page.
class FlatsScreen extends StatefulWidget {
  const FlatsScreen({super.key});

  @override
  State<FlatsScreen> createState() => _FlatsScreenState();
}

class _FlatsScreenState extends State<FlatsScreen> {
  void _refresh() => setState(() {});

  Future<void> _openDetail(Flat flat) async {
    await Navigator.pushNamed(context, Routes.flatDetail, arguments: flat.id);
    if (mounted) _refresh();
  }

  Future<void> _openCreateForm() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const FlatCreateScreen()),
    );
    if (created == true && mounted) _refresh();
  }

  Future<void> _openEditFlow() async {
    final store = StoreScope.of(context);
    final active =
        store.flats.where((f) => !f.archived).toList(growable: false);
    if (active.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('No flats to edit yet.')));
      return;
    }
    final selected = await showDialog<Flat>(
      context: context,
      builder: (_) => _FlatPickerDialog(flats: active),
    );
    if (selected == null || !mounted) return;
    final edited = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => FlatEditScreen(flat: selected)),
    );
    if (edited == true && mounted) _refresh();
  }

  Future<void> _deleteFlat(Flat flat) async {
    final store = StoreScope.of(context);
    final decision = FlatDeletionService.resolveDelete(
      flat: flat,
      expenses: store.expenses,
      leaseChequeRecords: store.leaseChequeRecords,
      payments: store.payments,
      leaseChequeSettings: store.leaseChequeSettings,
    );

    // If there's an outstanding due, show pay-or-leave dialog first
    if (decision.hasOutstandingDue) {
      final payOrLeave = await _showPayOrLeaveDialog(flat, decision.outstandingDue!);
      if (payOrLeave == null || !mounted) return;
      
      if (payOrLeave) {
        // Pay now: create a final LeaseChequeRecord
        final amount = await _showPayAmountDialog(decision.outstandingDue!);
        if (amount == null || !mounted) return;
        
        final setting = store.leaseChequeSettings
            .where((s) => s.flatId == flat.id)
            .firstOrNull;
        if (setting != null) {
          final record = LeaseChequeRecord(
            id: newId(),
            flatId: flat.id,
            ownerName: setting.ownerName,
            amount: amount,
            dueDate: setting.nextDueDate,
            paidDate: DateTime.now(),
            month: monthKey(setting.nextDueDate),
          );
          store.upsertChequeRecord(record);
        }
      }
      // "Leave it" - proceed without creating a record
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${flat.name}?'),
        content: Text(decision.confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm_delete_flat'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(decision.isHardDelete ? 'Delete' : 'Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (decision.isHardDelete) {
      // History-free flat: remove it AND its beds entirely, no trace.
      store.runBatched(() {
        for (final bed
            in store.beds.where((b) => b.flatId == flat.id).toList()) {
          store.deleteBed(bed.id);
        }
        store.deleteFlat(flat.id);
      });
    } else {
      // Soft delete: keep every record, just move out of the main grid.
      store.upsertFlat(flat.copyWith(archived: true, archivedAt: DateTime.now()));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${flat.name} ${decision.isHardDelete ? 'deleted' : 'archived'}')));
    _refresh();
  }

  Future<bool?> _showPayOrLeaveDialog(Flat flat, double outstandingAmount) async {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Outstanding Lease Due for ${flat.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This flat has an unpaid lease cheque of ${formatMoneyShort(outstandingAmount)}.',
            ),
            const SizedBox(height: 12),
            const Text('What would you like to do?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Leave it'),
          ),
          FilledButton(
            key: const Key('pay_now_button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Pay now'),
          ),
        ],
      ),
    );
  }

  Future<double?> _showPayAmountDialog(double defaultAmount) async {
    final controller = TextEditingController(text: formatMoney(defaultAmount));
    return showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pay Outstanding Due'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Amount (AED)',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
              ],
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(controller.text.trim().replaceAll(',', ''));
              Navigator.pop(dialogContext, amount);
            },
            child: const Text('Pay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final flats = store.flats.where((f) => !f.archived).toList();
    final beds = store.beds;

    if (flats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.apartment_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text('No flats yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  key: const Key('add_flat_empty_state'),
                  onPressed: _openCreateForm,
                  icon: const Icon(Icons.add),
                  label: const Text('Add flat'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  key: const Key('edit_flats_button_empty_state'),
                  onPressed: _openEditFlow,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
        ),
        itemCount: flats.length,
        itemBuilder: (context, index) {
          final flat = flats[index];
          final flatBeds =
              beds.where((b) => b.flatId == flat.id).toList(growable: false);
          final occupied = flatBeds.where((b) => b.isOccupied).length;
          return _FlatCard(
            key: ValueKey('flat-card-${flat.id}'),
            flat: flat,
            occupiedBeds: occupied,
            totalBeds: flatBeds.length,
            onTap: () => _openDetail(flat),
            onDelete: () => _deleteFlat(flat),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            key: const Key('edit_flats_button'),
            heroTag: 'edit_flats',
            onPressed: _openEditFlow,
            tooltip: 'Edit flats',
            child: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            key: const Key('add_flats_button'),
            onPressed: _openCreateForm,
            icon: const Icon(Icons.add),
            label: const Text('Add flat'),
          ),
        ],
      ),
    );
  }
}

class _FlatCard extends StatelessWidget {
  const _FlatCard({
    super.key,
    required this.flat,
    required this.occupiedBeds,
    required this.totalBeds,
    required this.onTap,
    required this.onDelete,
  });

  final Flat flat;
  final int occupiedBeds;
  final int totalBeds;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      flat.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    width: 28,
                    child: IconButton(
                      key: ValueKey('delete-flat-${flat.id}'),
                      tooltip: 'Delete flat',
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$occupiedBeds / $totalBeds beds',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picker shown before the edit form opens: lists active, non-archived flats.
class _FlatPickerDialog extends StatelessWidget {
  const _FlatPickerDialog({required this.flats});

  final List<Flat> flats;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit which flat?'),
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

/// Full-screen flat creation form. On save, [FlatCreationService] creates the
/// flat, its N beds and the lease cheque setting in one atomic write.
class FlatCreateScreen extends StatefulWidget {
  const FlatCreateScreen({super.key});

  @override
  State<FlatCreateScreen> createState() => _FlatCreateScreenState();
}

/// Shared form state for create + edit so both flows stay identical.
mixin _FlatFormMixin<T extends StatefulWidget> on State<T> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController contractPersonController =
      TextEditingController();
  final TextEditingController yearlyRentController = TextEditingController();
  final TextEditingController frequencyController = TextEditingController(text: '2');

  DateTime? registeredDate;
  DateTime? leasePaidThroughDate;
  int frequencyMonths = 2;

  double? parseMoney(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', ''));
    return (value == null || value < 0) ? null : value;
  }

  int? parseInt(String raw) {
    final value = int.tryParse(raw.trim());
    return (value == null || value < 1) ? null : value;
  }

  String dateText(DateTime date) =>
      '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<void> pickRegisteredDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: registeredDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => registeredDate = picked);
  }

  Future<void> pickLeasePaidThroughDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: leasePaidThroughDate ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (picked != null) setState(() => leasePaidThroughDate = picked);
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    contractPersonController.dispose();
    yearlyRentController.dispose();
    frequencyController.dispose();
    super.dispose();
  }
}

class _FlatCreateScreenState extends State<FlatCreateScreen>
    with _FlatFormMixin {
  FlatCreationService? _service;
  final _bedCountController = TextEditingController(text: '5');
  final _defaultRentController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service ??= FlatCreationService(StoreScope.of(context));
  }

  @override
  void dispose() {
    _bedCountController.dispose();
    _defaultRentController.dispose();
    super.dispose();
  }

  int? _parseBedCount(String raw) {
    final value = int.tryParse(raw.trim());
    return BedCapacityService.canCreateFlat(value ?? 0) ? value : null;
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final service = _service;
    if (service == null) return;

    final frequency = parseInt(frequencyController.text);
    if (frequency == null || frequency < 1 || frequency > 12) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Frequency must be 1–12 months')));
      return;
    }

    try {
      service.createFlat(
        name: nameController.text,
        address: addressController.text,
        registeredDate: registeredDate,
        contractPerson: contractPersonController.text,
        yearlyRent: parseMoney(yearlyRentController.text)!,
        bedCount: _parseBedCount(_bedCountController.text)!,
        defaultRentPerBed: parseMoney(_defaultRentController.text)!,
        leasePaidThroughDate: leasePaidThroughDate,
        frequencyMonths: frequency,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('${nameController.text.trim()} created')));
      Navigator.pop(context, true);
    } on FlatCreationException catch (error) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add flat')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Flat name',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: pickLeasePaidThroughDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(
                leasePaidThroughDate == null
                    ? 'Lease paid through (onboarding)'
                    : 'Lease paid through ${dateText(leasePaidThroughDate!)}',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: frequencyController,
              decoration: const InputDecoration(
                labelText: 'Payment frequency (months)',
                helperText: 'Months between lease payments (1–12)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              validator: (value) {
                final v = parseInt(value ?? '');
                if (v == null || v < 1 || v > 12) return 'Enter 1–12';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: contractPersonController,
              decoration: const InputDecoration(
                labelText: 'Contract person',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: yearlyRentController,
              decoration: InputDecoration(
                labelText: 'Yearly rent (${AppConfig.currencySymbol})',
                border: const OutlineInputBorder(),
                helperText:
                    'Lease cheque auto-calculated as yearly rent ÷ (12 ÷ frequency)',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
              ],
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  parseMoney(value ?? '') == null ? 'Enter a valid amount' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bedCountController,
              decoration: const InputDecoration(
                labelText: 'Total beds',
                helperText:
                    '${BedCapacityService.minBeds}–${BedCapacityService.maxBeds} beds',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              validator: (value) => _parseBedCount(value ?? '') == null
                  ? 'Must be ${BedCapacityService.minBeds}–'
                      '${BedCapacityService.maxBeds}'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _defaultRentController,
              decoration: InputDecoration(
                labelText:
                    'Default rent per bed (${AppConfig.currencySymbol})',
                border: const OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
              ],
              validator: (value) =>
                  parseMoney(value ?? '') == null ? 'Enter a valid amount' : null,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Create flat'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Combined flat + beds edit form. Covers both flat fields (name, address,
/// registeredDate, contractPerson, yearlyRent) and bed management (add/remove
/// beds within the 5–20 rule, edit each bed's label/default rent) in one
/// screen, saved as one atomic batch.
class FlatEditScreen extends StatefulWidget {
  const FlatEditScreen({super.key, required this.flat});

  final Flat flat;

  @override
  State<FlatEditScreen> createState() => _FlatEditScreenState();
}

class _FlatEditScreenState extends State<FlatEditScreen> with _FlatFormMixin {
  List<_BedDraft>? _bedsDrafts;

  List<_BedDraft> get _beds => _bedsDrafts ??= _loadBeds();

  List<_BedDraft> _loadBeds() {
    final existing = StoreScope.of(context)
        .beds
        .where((b) => b.flatId == widget.flat.id)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return existing.map(_BedDraft.fromBed).toList();
  }

  @override
  void initState() {
    super.initState();
    final flat = widget.flat;
    nameController.text = flat.name;
    addressController.text = flat.address;
    contractPersonController.text = flat.contractPerson ?? '';
    yearlyRentController.text = formatMoney(flat.yearlyRent ?? 0);
    registeredDate = flat.registeredDate;
    leasePaidThroughDate = flat.leasePaidThroughDate;
    frequencyMonths = flat.frequencyMonths;
    frequencyController.text = flat.frequencyMonths.toString();
  }

  bool get _canAddBed => _beds.length < BedCapacityService.maxBeds;
  bool get _canRemoveBed => _beds.length > BedCapacityService.minBeds;

  void _addBed() {
    if (!_canAddBed) return;
    setState(() {
      var index = 1;
      while (_beds.any((d) => d.label == 'Bed $index')) {
        index++;
      }
      _beds.add(_BedDraft(id: null, label: 'Bed $index', rent: _guessRent()));
    });
  }

  double _guessRent() {
    for (final draft in _beds) {
      if (draft.rent > 0) return draft.rent;
    }
    return 0;
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (_beds.length < BedCapacityService.minBeds ||
        _beds.length > BedCapacityService.maxBeds) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(
                'A flat must have between ${BedCapacityService.minBeds} and '
                '${BedCapacityService.maxBeds} beds.')));
      return;
    }
    
    final frequency = parseInt(frequencyController.text);
    if (frequency == null || frequency < 1 || frequency > 12) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Frequency must be 1–12 months')));
      return;
    }

    final store = StoreScope.of(context);
    final yearlyRent = parseMoney(yearlyRentController.text);

    store.runBatched(() {
      store.upsertFlat(widget.flat.copyWith(
        name: nameController.text.trim(),
        address: addressController.text.trim(),
        registeredDate: registeredDate,
        clearRegisteredDate: registeredDate == null,
        contractPerson: contractPersonController.text.trim(),
        yearlyRent: yearlyRent,
        leasePaidThroughDate: leasePaidThroughDate,
        clearLeasePaidThroughDate: leasePaidThroughDate == null,
        frequencyMonths: frequency,
      ));
      final keptIds = <String>{};
      for (final draft in _beds) {
        final id = draft.id ?? newId();
        keptIds.add(id);
        store.upsertBed(Bed(
          id: id,
          flatId: widget.flat.id,
          label: draft.label.trim(),
          defaultMonthlyRent: draft.rent,
          tenantId: draft.tenantId,
        ));
      }
      // Beds removed in the form disappear from the store entirely.
      for (final bed in store.beds
          .where((b) => b.flatId == widget.flat.id && !keptIds.contains(b.id))
          .toList()) {
        store.deleteBed(bed.id);
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${widget.flat.name} updated')));
    Navigator.pop(context, true);
  }

  /// Fresh ids only when adding new beds; keeps existing beds stable.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit flat')),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Flat name',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: pickRegisteredDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      registeredDate == null
                          ? 'Flat registered on'
                          : 'Flat registered on ${dateText(registeredDate!)}',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Clear registration date',
                  onPressed: () => setState(() => registeredDate = null),
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: pickLeasePaidThroughDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      leasePaidThroughDate == null
                          ? 'Lease paid through (onboarding)'
                          : 'Lease paid through ${dateText(leasePaidThroughDate!)}',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Clear lease paid through date',
                  onPressed: () => setState(() => leasePaidThroughDate = null),
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: frequencyController,
              decoration: const InputDecoration(
                labelText: 'Payment frequency (months)',
                helperText: 'Months between lease payments (1–12)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final v = parseInt(value ?? '');
                if (v == null || v < 1 || v > 12) return 'Enter 1–12';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: contractPersonController,
              decoration: const InputDecoration(
                labelText: 'Contract person',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: yearlyRentController,
              decoration: InputDecoration(
                labelText: 'Yearly rent (${AppConfig.currencySymbol})',
                border: const OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
              ],
              validator: (value) =>
                  parseMoney(value ?? '') == null ? 'Enter a valid amount' : null,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text('Beds (${_beds.length})',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  key: const Key('add_bed_button'),
                  tooltip: 'Add bed',
                  onPressed: _canAddBed ? _addBed : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            ..._beds.asMap().entries.map((entry) {
              final index = entry.key;
              final draft = entry.value;
              return Card(
                key: draft.stateKey,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: draft.label,
                              decoration: const InputDecoration(
                                labelText: 'Label',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) => draft.label = v,
                              validator: (v) => (v == null ||
                                      v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          IconButton(
                            key: ValueKey('remove-bed-${draft.stateKey}'),
                            tooltip: 'Remove bed',
                            onPressed: _canRemoveBed
                                ? () => setState(() => _beds.removeAt(index))
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue:
                            draft.rent == 0 ? '' : formatMoney(draft.rent),
                        decoration: InputDecoration(
                          labelText:
                              'Default monthly rent (${AppConfig.currencySymbol})',
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*[.,]?\d*')),
                        ],
                        onChanged: (v) =>
                            draft.rent = parseMoney(v) ?? draft.rent,
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('save_flat_edit'),
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mutable working copy of a bed inside the edit form.
class _BedDraft {
  _BedDraft({required this.id, required this.label, required this.rent, this.tenantId});

  factory _BedDraft.fromBed(Bed bed) => _BedDraft(
        id: bed.id,
        label: bed.label,
        rent: bed.defaultMonthlyRent,
        tenantId: bed.tenantId,
      );

  /// Existing bed id, or null while the bed is brand new.
  final String? id;
  String label;
  double rent;
  final String? tenantId;

  Key get stateKey => Key('bed-draft-${id ?? label}');
}
