import 'package:flutter/material.dart';

import '../config.dart';
import '../models/bed.dart';
import '../models/flat.dart';
import '../models/lease_cheque_setting.dart';
import '../models/payment.dart';
import '../models/person.dart';
import '../services/assignment_service.dart';
import '../services/bed_capacity_service.dart';
import '../services/json_store.dart';
import '../services/tenure_service.dart';
import '../utils/format.dart';
import '../utils/ids.dart';
import '../widgets/bed_capacity_hint.dart';
import '../widgets/cheque_editor.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/empty_state.dart';
import 'person_history_screen.dart';

class FlatDetailScreen extends StatefulWidget {
  const FlatDetailScreen({super.key, required this.store, required this.flat});

  final JsonStore store;
  final Flat flat;

  @override
  State<FlatDetailScreen> createState() => _FlatDetailScreenState();
}

class _FlatDetailScreenState extends State<FlatDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Flat _flat;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _flat = widget.flat;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Bed> get _beds =>
      widget.store.beds.where((b) => b.flatId == widget.flat.id).toList();

  Future<void> _openFlatForm() async {
    final result = await showModalBottomSheet<({Flat flat, int bedCount})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FlatForm(existing: _flat),
    );
    if (result == null) return;
    setState(() {
      widget.store.upsertFlat(result.flat);
      final previous = _flat;
      if (result.flat.yearlyRent != previous.yearlyRent &&
          result.flat.yearlyRent != null) {
        final setting = widget.store.leaseChequeSettings
            .where((s) => s.flatId == result.flat.id)
            .firstOrNull;
        if (setting != null) {
          widget.store.upsertChequeSetting(
            setting.copyWith(amount: result.flat.yearlyRent! / 6),
          );
        }
      }
      _flat = result.flat;
    });
  }

  Future<void> _deleteFlat() async {
    final beds = _beds;
    final occupied = beds.where((b) => b.tenantId != null).length;
    final detail = beds.isEmpty
        ? 'This flat has no beds. Delete it?'
        : 'This flat has ${beds.length} '
            'bed${beds.length == 1 ? '' : 's'} and $occupied active '
            'tenant${occupied == 1 ? '' : 's'} — delete anyway?';
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete ${_flat.name}?',
      detail: detail,
    );
    if (!confirmed) return;
    widget.store.deleteFlat(_flat.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${_flat.name}')),
    );
  }

  Future<void> _openBedForm({Bed? existing}) async {
    final result = await showModalBottomSheet<Bed>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BedForm(
        flatId: widget.flat.id,
        existing: existing,
      ),
    );
    if (result == null) return;
    setState(() {
      widget.store.upsertBed(result);
    });
  }

  Future<void> _deleteBed(Bed bed) async {
    final tenant = widget.store.people.where((p) => p.id == bed.tenantId);
    final tenantName = tenant.isEmpty ? null : tenant.first.name;
    final detail = tenantName == null
        ? 'This bed is vacant. Delete it?'
        : '$tenantName is currently assigned to this bed. Deleting the bed '
            'will also unassign them. Their payment history is kept. Delete?';
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete ${bed.label}?',
      detail: detail,
    );
    if (!confirmed) return;
    setState(() {
      widget.store.deleteBed(bed.id);
    });
  }

  Future<void> _assignTenant(Bed bed) async {
    final result = await showModalBottomSheet<({Person person, double deposit})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignTenantForm(bed: bed),
    );
    if (result == null || !mounted) return;
    final assignments = AssignmentService(widget.store);
    assignments.assignTenant(
      bed: bed,
      person: result.person,
      deposit: result.deposit,
      joinDate: result.person.joinDate!,
      plannedStayMonths: result.person.plannedStayMonths!,
      monthlyRent: result.person.monthlyRent,
    );
    setState(() {});
  }

  void _openPerson(Person person) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonHistoryScreen(
          store: widget.store,
          person: person,
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _openChequeEditor(LeaseChequeSetting setting) async {
    final updated = await showChequeEditor(context, setting);
    if (updated == null) return;
    setState(() {
      widget.store.upsertChequeSetting(updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final beds = _beds;
    final canAdd = BedCapacityService.canAddBed(beds);
    final canDelete = BedCapacityService.canDeleteBed(beds);
    return Scaffold(
      appBar: AppBar(
        title: Text(_flat.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit flat',
            onPressed: _openFlatForm,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete flat',
            onPressed: _deleteFlat,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Beds'), Tab(text: 'Lease info')],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              heroTag: 'flat-detail-fab',
              onPressed: canAdd
                  ? () => _openBedForm()
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Cannot add a bed: this flat already has '
                            '${BedCapacityService.maxBeds} beds (the maximum).',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.add),
              label: Text(canAdd ? 'Add bed' : 'Full at 20'),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _BedsTab(
            beds: beds,
            store: widget.store,
            canDelete: canDelete,
            onAddBed: () => _openBedForm(),
            onEditBed: (bed) => _openBedForm(existing: bed),
            onDeleteBed: (bed) => _deleteBed(bed),
            onTapBed: (bed) {
              if (bed.isOccupied) {
                final tenant = widget.store.people
                    .where((p) => p.id == bed.tenantId)
                    .firstOrNull;
                if (tenant != null) _openPerson(tenant);
              } else {
                _assignTenant(bed);
              }
            },
          ),
          _LeaseInfoTab(
            store: widget.store,
            flat: _flat,
            onEditCheque: (setting) => _openChequeEditor(setting),
          ),
        ],
      ),
    );
  }
}

class _BedsTab extends StatefulWidget {
  const _BedsTab({
    required this.beds,
    required this.store,
    required this.canDelete,
    required this.onAddBed,
    required this.onEditBed,
    required this.onDeleteBed,
    required this.onTapBed,
  });

  final List<Bed> beds;
  final JsonStore store;
  final bool canDelete;
  final VoidCallback onAddBed;
  final ValueChanged<Bed> onEditBed;
  final ValueChanged<Bed> onDeleteBed;
  final ValueChanged<Bed> onTapBed;

  @override
  State<_BedsTab> createState() => _BedsTabState();
}

class _BedsTabState extends State<_BedsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isOverdue(Bed bed) {
    final person = widget.store.people
        .where((p) => p.id == bed.tenantId)
        .firstOrNull;
    if (person == null) return false;
    final month = monthKey(DateTime.now());
    return widget.store.payments.any(
      (p) =>
          p.personId == person.id &&
          p.type == PaymentType.rent &&
          p.month == month &&
          p.status != PaymentStatus.paid,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final beds = widget.beds;
    final store = widget.store;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  store.flats.where((f) => f.id == beds.firstOrNull?.flatId).firstOrNull?.address ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              BedCapacityHint(count: beds.length),
            ],
          ),
        ),
        Expanded(
          child: beds.isEmpty
              ? EmptyState(
                  icon: Icons.bed,
                  message: 'No beds in this flat yet. Add a bed to start '
                      'tracking occupancy.',
                  actionLabel: 'Add bed',
                  onAction: widget.onAddBed,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  itemCount: beds.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final bed = beds[index];
                    final tenant = store.people
                        .where((p) => p.id == bed.tenantId)
                        .firstOrNull;
                    final rent =
                        tenant?.monthlyRent ?? bed.defaultMonthlyRent;
                    final overdue = bed.isOccupied && _isOverdue(bed);
                    final accent = !bed.isOccupied
                        ? Colors.grey
                        : overdue
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary;
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: Border(
                        left: BorderSide(
                          color: !bed.isOccupied
                              ? Colors.grey.shade400
                              : accent,
                          width: 4,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: accent.withValues(alpha: 0.15),
                          child: Icon(
                            bed.isOccupied ? Icons.person : Icons.bed_outlined,
                            color: accent,
                          ),
                        ),
                        title: Text(bed.label),
                        subtitle: tenant == null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Vacant',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              )
                            : Text(tenant.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tenant != null && rent > 0)
                              Text('AED ${rent.toStringAsFixed(0)}/month'),
                            if (tenant == null)
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: 'Assign tenant',
                                onPressed: () => widget.onTapBed(bed),
                              ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              tooltip: 'Bed actions',
                              onSelected: (value) {
                              if (value == 'edit') widget.onEditBed(bed);
                              if (value == 'delete') {
                                if (widget.canDelete) {
                                  widget.onDeleteBed(bed);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Cannot delete a bed: a flat '
                                        'must keep at least '
                                        '${BedCapacityService.minBeds} '
                                        'beds.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit bed'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete bed'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => widget.onTapBed(bed),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _LeaseInfoTab extends StatefulWidget {
  const _LeaseInfoTab({
    required this.store,
    required this.flat,
    required this.onEditCheque,
  });

  final JsonStore store;
  final Flat flat;
  final ValueChanged<LeaseChequeSetting> onEditCheque;

  @override
  State<_LeaseInfoTab> createState() => _LeaseInfoTabState();
}

class _LeaseInfoTabState extends State<_LeaseInfoTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final flat = widget.flat;
    final store = widget.store;
    final setting =
        store.leaseChequeSettings.where((s) => s.flatId == flat.id).firstOrNull;
    final records = store.leaseChequeRecords
        .where((r) => r.flatId == flat.id)
        .toList()
      ..sort((a, b) => b.paidDate.compareTo(a.paidDate));

    Widget infoRow(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(child: Text(value)),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text('Lease agreement', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        infoRow('Address', flat.address),
        infoRow(
          'Contract date',
          flat.contractDate == null
              ? '—'
              : '${flat.contractDate!.day}/${flat.contractDate!.month}/${flat.contractDate!.year}',
        ),
        infoRow('Contract person', flat.contractPerson ?? '—'),
        infoRow(
          'Yearly rent',
          flat.yearlyRent == null ? '—' : 'AED ${formatMoney(flat.yearlyRent!)}',
        ),
        const Divider(height: 32),
        Text('Current cheque', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (setting == null)
          const Text('No cheque set up for this flat.')
        else
          Card(
            child: ListTile(
              title: Text(
                'AED ${formatMoney(setting.amount)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                '${setting.ownerName.isEmpty ? 'Owner not set' : setting.ownerName}\n'
                'Next due ${setting.nextDueDate.day}/${setting.nextDueDate.month}/${setting.nextDueDate.year}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit cheque',
                onPressed: () => widget.onEditCheque(setting),
              ),
              onTap: () => widget.onEditCheque(setting),
            ),
          ),
        const Divider(height: 32),
        Text('Cheque history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (records.isEmpty)
          const Text('No cheques paid yet.')
        else
          ...records.map(
            (r) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.request_quote_outlined),
                title: Text('AED ${formatMoney(r.amount)}'),
                subtitle: Text(
                  '${r.ownerName.isEmpty ? 'Owner not set' : r.ownerName}\n'
                  'Due ${r.dueDate.day}/${r.dueDate.month}/${r.dueDate.year} · '
                  'paid ${r.paidDate.day}/${r.paidDate.month}/${r.paidDate.year}',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FlatForm extends StatefulWidget {
  const _FlatForm({required this.existing});

  final Flat existing;

  @override
  State<_FlatForm> createState() => _FlatFormState();
}

class _FlatFormState extends State<_FlatForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _contractPerson;
  late final TextEditingController _yearlyRent;
  DateTime? _contractDate;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing.name);
    _address = TextEditingController(text: widget.existing.address);
    _contractPerson =
        TextEditingController(text: widget.existing.contractPerson ?? '');
    _yearlyRent = TextEditingController(
      text: widget.existing.yearlyRent == null
          ? ''
          : widget.existing.yearlyRent!.toStringAsFixed(0),
    );
    _contractDate = widget.existing.contractDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _contractPerson.dispose();
    _yearlyRent.dispose();
    super.dispose();
  }

  Future<void> _pickContractDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _contractDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _contractDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final yearlyRent = double.tryParse(_yearlyRent.text.trim());
    Navigator.of(context).pop(
      (
        flat: widget.existing.copyWith(
          name: _name.text.trim(),
          address: _address.text.trim(),
          contractDate: _contractDate,
          contractPerson: _contractPerson.text.trim().isEmpty
              ? null
              : _contractPerson.text.trim(),
          yearlyRent: yearlyRent,
        ),
        bedCount: 0,
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
                'Edit flat',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Flat name',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Address is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contractPerson,
                decoration: const InputDecoration(
                  labelText: 'Contract person',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearlyRent,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Yearly rent',
                  helperText: 'Cheque amount auto-fills as yearly rent ÷ 6.',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickContractDate,
                icon: const Icon(Icons.event),
                label: Text(
                  _contractDate == null
                      ? 'Contract date'
                      : 'Contract: ${_contractDate!.day}/${_contractDate!.month}/${_contractDate!.year}',
                ),
              ),
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

class _BedForm extends StatefulWidget {
  const _BedForm({required this.flatId, this.existing});

  final String flatId;
  final Bed? existing;

  @override
  State<_BedForm> createState() => _BedFormState();
}

class _BedFormState extends State<_BedForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _rent;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.existing?.label ?? '');
    _rent = TextEditingController(
      text: widget.existing == null
          ? ''
          : widget.existing!.defaultMonthlyRent.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _label.dispose();
    _rent.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final rent = double.tryParse(_rent.text.trim());
    Navigator.of(context).pop(
      Bed(
        id: widget.existing?.id ?? newId(),
        flatId: widget.flatId,
        label: _label.text.trim(),
        defaultMonthlyRent: rent ?? 0,
        tenantId: widget.existing?.tenantId,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Add bed' : 'Edit bed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _label,
              decoration: const InputDecoration(
                labelText: 'Label (e.g. Bed A1)',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Label is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rent,
              decoration: const InputDecoration(
                labelText: 'Monthly rent',
                prefixText: '${AppConfig.currencySymbol} ',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Rent is required';
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignTenantForm extends StatefulWidget {
  const _AssignTenantForm({required this.bed});

  final Bed bed;

  @override
  State<_AssignTenantForm> createState() => _AssignTenantFormState();
}

class _AssignTenantFormState extends State<_AssignTenantForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _workplace;
  late final TextEditingController _others;
  late final TextEditingController _plannedStay;
  late final TextEditingController _monthlyRent;
  late final TextEditingController _deposit;
  late DateTime _joinDate;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _contact = TextEditingController();
    _workplace = TextEditingController();
    _others = TextEditingController();
    _plannedStay = TextEditingController(text: '3');
    _monthlyRent = TextEditingController(
      text: widget.bed.defaultMonthlyRent <= 0
          ? ''
          : widget.bed.defaultMonthlyRent.toStringAsFixed(0),
    );
    _deposit = TextEditingController();
    _joinDate = DateTime.now();
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _workplace.dispose();
    _others.dispose();
    _plannedStay.dispose();
    _monthlyRent.dispose();
    _deposit.dispose();
    super.dispose();
  }

  Future<void> _pickJoinDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked == null) return;
    setState(() => _joinDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final plannedStay = int.tryParse(_plannedStay.text.trim()) ?? 0;
    final monthlyRent = double.tryParse(_monthlyRent.text.trim());
    final deposit = double.tryParse(_deposit.text.trim()) ?? 0;
    final person = Person(
      id: newId(),
      name: _name.text.trim(),
      contact: _contact.text.trim(),
      workplaceOrInfo:
          _workplace.text.trim().isEmpty ? null : _workplace.text.trim(),
      others: _others.text.trim().isEmpty ? null : _others.text.trim(),
      bedId: widget.bed.id,
      joinDate: _joinDate,
      plannedStayMonths: plannedStay,
      vacatedDate: TenureService.computedLeaveDate(_joinDate, plannedStay),
      monthlyRent: monthlyRent,
      depositAmount: deposit,
    );
    Navigator.of(context).pop((person: person, deposit: deposit));
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
                'Assign ${widget.bed.label}',
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
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _workplace,
                decoration: const InputDecoration(
                  labelText: 'Workplace / info',
                  border: OutlineInputBorder(),
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
                textInputAction: TextInputAction.next,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickJoinDate,
                icon: const Icon(Icons.event),
                label: Text(
                  'Joined: ${_joinDate.day}/${_joinDate.month}/${_joinDate.year}',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _plannedStay,
                      decoration: const InputDecoration(
                        labelText: 'Planned stay (months)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final parsed = int.tryParse(v?.trim() ?? '');
                        if (parsed == null || parsed < 1) {
                          return 'Min 1 month';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
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
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deposit,
                decoration: const InputDecoration(
                  labelText: 'Deposit',
                  prefixText: '${AppConfig.currencySymbol} ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) {
                  final parsed = double.tryParse(v?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Deposit must be more than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: const Text('Assign'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}