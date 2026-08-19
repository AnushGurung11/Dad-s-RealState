import 'package:flutter/material.dart';

import '../models/bed.dart';
import '../models/person.dart';
import '../services/assignment_service.dart';
import '../services/json_store.dart';
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
    setState(() {
      _assignments.assignTenant(bedId: chosen.id, personId: person.id);
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
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: const Icon(Icons.person),
                    ),
                    title: Text(person.name),
                    subtitle: Text(
                      bed.isEmpty ? bedLabel : '$bedLabel · $flatName\n${person.phone}',
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
  late final TextEditingController _phone;
  DateTime? _moveInDate;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _moveInDate = widget.existing?.moveInDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _moveInDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _moveInDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Person(
        id: widget.existing?.id ?? newId(),
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        bedId: widget.existing?.bedId,
        moveInDate: _moveInDate ?? DateTime.now(),
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
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(
                _moveInDate == null
                    ? 'Pick move-in date'
                    : 'Move-in: ${_moveInDate!.day}/${_moveInDate!.month}/${_moveInDate!.year}',
              ),
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