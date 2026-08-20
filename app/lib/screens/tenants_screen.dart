import 'package:flutter/material.dart';

import '../config.dart';

import '../models/bed.dart';
import '../models/person.dart';
import '../services/assignment_service.dart';
import '../services/json_store.dart';
import '../services/tenure_service.dart';
import '../utils/format.dart';
import '../utils/ids.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/empty_state.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key, required this.store});

  final JsonStore store;

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  late final AssignmentService _assignments;

  @override
  void initState() {
    super.initState();
    _assignments = AssignmentService(widget.store);
  }

  Future<void> _openPersonForm({Person? existing}) async {
    final result = await showModalBottomSheet<Person>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PersonForm(existing: existing),
    );
    if (result == null) return;
    setState(() {
      widget.store.upsertPerson(result);
    });
  }

  Future<void> _deletePerson(Person person) async {
    final bed = widget.store.beds.where((b) => b.id == person.bedId);
    final detail = bed.isEmpty
        ? '${person.name} has no bed assigned. Their payment history will be kept. Delete?'
        : '${person.name} is assigned to ${bed.first.label}. They will be unassigned and their payment history kept. Delete?';
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete ${person.name}?',
      detail: detail,
    );
    if (!confirmed) return;
    setState(() {
      widget.store.deletePerson(person.id);
    });
  }

  Future<void> _openAssignPicker(Person person) async {
    if (person.hasBed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Unassign ${person.name}?'),
          content: const Text(
            'They will be unassigned from their bed. Payment history is kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Unassign'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() {
        _assignments.unassignTenant(person.bedId!);
      });
      return;
    }

    final allBeds = widget.store.beds.where((b) => b.tenantId == null).toList();
    if (allBeds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vacant beds available to assign.')),
      );
      return;
    }

    final chosen = await showModalBottomSheet<Bed>(
      context: context,
      builder: (context) {
        final flats = widget.store.flats;
        String flatName(String flatId) {
          final match = flats.where((f) => f.id == flatId);
          return match.isEmpty ? 'Unknown flat' : match.first.name;
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Assign ${person.name}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final bed in allBeds)
                      ListTile(
                        leading: const Icon(Icons.bed_outlined),
                        title: Text(bed.label),
                        subtitle: Text(
                          '${flatName(bed.flatId)} · ${formatMoneyShort(bed.monthlyRent)}/month',
                        ),
                        onTap: () => Navigator.pop(context, bed),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (chosen == null) return;
    await _openAssignmentForm(person: person, bed: chosen);
  }

  Future<void> _openAssignmentForm({
    required Person person,
    required Bed bed,
  }) async {
    final result = await showModalBottomSheet<({double deposit, DateTime joinDate, int stayMonths, DateTime leaveDate})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignmentForm(store: widget.store, person: person, bed: bed),
    );
    if (result == null) return;
    setState(() {
      _assignments.assignTenant(
        bed: bed,
        person: person,
        deposit: result.deposit,
        joinDate: result.joinDate,
        plannedStayMonths: result.stayMonths,
      );
      final updated = widget.store.people.where((p) => p.id == person.id).firstOrNull;
      if (updated != null && result.leaveDate != updated.leaveDate) {
        widget.store.upsertPerson(updated.copyWith(leaveDate: result.leaveDate));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final people = widget.store.people;
    return Scaffold(
      appBar: AppBar(title: const Text('Tenants')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'tenants-fab',
        onPressed: () => _openPersonForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add tenant'),
      ),
      body: people.isEmpty
          ? EmptyState(
              icon: Icons.group_outlined,
              message: 'No tenants yet. Add a tenant to assign them a bed.',
              actionLabel: 'Add tenant',
              onAction: () => _openPersonForm(),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final person = people[index];
                final bed = widget.store.beds.where((b) => b.id == person.bedId);
                final bedLabel =
                    bed.isEmpty ? 'No bed assigned' : 'Bed ${bed.first.label}';
                final flatName = bed.isEmpty
                    ? ''
                    : widget.store.flats
                        .where((f) => f.id == bed.first.flatId)
                        .firstOrNull
                        ?.name ??
                        '';

                String? balanceText;
                if (person.isActiveTenant && bed.isNotEmpty) {
                  final balance = TenureService.remainingBalance(
                    person,
                    bed.first.monthlyRent,
                    widget.store.payments,
                  );
                  balanceText = 'Balance ${formatMoneyShort(balance)}';
                }

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: const Icon(Icons.person),
                    ),
                    title: Text(person.name),
                    subtitle: Text(
                      [
                        if (bed.isEmpty) bedLabel else '$bedLabel · $flatName',
                        person.contact,
                        ?balanceText,
                      ].join('\n'),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            person.hasBed
                                ? Icons.link_off
                                : Icons.link,
                          ),
                          tooltip: person.hasBed ? 'Unassign bed' : 'Assign bed',
                          onPressed: () => _openAssignPicker(person),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit tenant',
                          onPressed: () => _openPersonForm(existing: person),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete tenant',
                          onPressed: () => _deletePerson(person),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _PersonForm extends StatefulWidget {
  const _PersonForm({this.existing});

  final Person? existing;

  @override
  State<_PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<_PersonForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _workplace;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _contact = TextEditingController(text: widget.existing?.contact ?? '');
    _workplace = TextEditingController(
      text: widget.existing?.workplaceOrInfo ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _workplace.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existing;
    Navigator.of(context).pop(
      Person(
        id: existing?.id ?? newId(),
        name: _name.text.trim(),
        contact: _contact.text.trim(),
        workplaceOrInfo: _workplace.text.trim().isEmpty
            ? null
            : _workplace.text.trim(),
        bedId: existing?.bedId,
        joinDate: existing?.joinDate,
        plannedStayMonths: existing?.plannedStayMonths,
        leaveDate: existing?.leaveDate,
        depositAmount: existing?.depositAmount,
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
              widget.existing == null ? 'Add tenant' : 'Edit tenant',
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
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
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
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Contact is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _workplace,
              decoration: const InputDecoration(
                labelText: 'Workplace / info (optional)',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
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

class _AssignmentForm extends StatefulWidget {
  const _AssignmentForm({
    required this.store,
    required this.person,
    required this.bed,
  });

  final JsonStore store;
  final Person person;
  final Bed bed;

  @override
  State<_AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends State<_AssignmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _deposit;
  late final TextEditingController _stayMonths;
  DateTime? _joinDate;
  DateTime? _leaveDate;
  bool _leaveDateEdited = false;

  @override
  void initState() {
    super.initState();
    _deposit = TextEditingController();
    _stayMonths = TextEditingController(text: '3');
    _joinDate = DateTime.now();
    _recomputeLeaveDate();
  }

  @override
  void dispose() {
    _deposit.dispose();
    _stayMonths.dispose();
    super.dispose();
  }

  void _recomputeLeaveDate() {
    final join = _joinDate;
    final months = int.tryParse(_stayMonths.text.trim());
    if (join != null && months != null && months >= 1) {
      _leaveDate = TenureService.computedLeaveDate(join, months);
      _leaveDateEdited = false;
    }
  }

  Future<void> _pickJoinDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _joinDate = picked;
      if (!_leaveDateEdited) _recomputeLeaveDate();
    });
  }

  Future<void> _pickLeaveDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _leaveDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _leaveDate = picked;
      _leaveDateEdited = true;
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final deposit = double.tryParse(_deposit.text.trim()) ?? 0;
    final months = int.tryParse(_stayMonths.text.trim()) ?? 0;
    Navigator.of(context).pop((
      deposit: deposit,
      joinDate: _joinDate!,
      stayMonths: months,
      leaveDate: _leaveDate!,
    ));
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
                'Assign ${widget.person.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.bed.label} · ${formatMoneyShort(widget.bed.monthlyRent)}/month',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deposit,
                decoration: const InputDecoration(
                  labelText: 'Deposit',
                  prefixText: '${AppConfig.currencySymbol} ',
                  helperText: 'Any positive amount.',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final parsed = double.tryParse(v?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Deposit must be more than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stayMonths,
                decoration: const InputDecoration(
                  labelText: 'Planned stay (months)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (!_leaveDateEdited) {
                    setState(_recomputeLeaveDate);
                  }
                },
                validator: (v) {
                  final parsed = int.tryParse(v?.trim() ?? '');
                  if (parsed == null || parsed < 1) {
                    return 'Enter at least 1 month';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickJoinDate,
                icon: const Icon(Icons.event),
                label: Text('Join date: ${_fmtDate(_joinDate!)}'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickLeaveDate,
                icon: const Icon(Icons.event_available),
                label: Text(
                  'Leave date: ${_fmtDate(_leaveDate!)} '
                  '${_leaveDateEdited ? '(edited)' : '(auto)'}',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _submit, child: const Text('Confirm')),
            ],
          ),
        ),
      ),
    );
  }
}