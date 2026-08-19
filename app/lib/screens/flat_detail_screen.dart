import 'package:flutter/material.dart';

import '../models/bed.dart';
import '../models/flat.dart';
import '../services/json_store.dart';
import '../utils/format.dart';
import '../utils/ids.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/empty_state.dart';

class FlatDetailScreen extends StatefulWidget {
  const FlatDetailScreen({super.key, required this.store, required this.flat});

  final JsonStore store;
  final Flat flat;

  @override
  State<FlatDetailScreen> createState() => _FlatDetailScreenState();
}

class _FlatDetailScreenState extends State<FlatDetailScreen> {
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

  @override
  Widget build(BuildContext context) {
    final beds = widget.store.beds.where((b) => b.flatId == widget.flat.id).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.flat.name)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'flat-detail-fab',
        onPressed: () => _openBedForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add bed'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              widget.flat.address,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: beds.isEmpty
                ? EmptyState(
                    icon: Icons.bed,
                    message: 'No beds in this flat yet. Add a bed to start '
                        'tracking occupancy.',
                    actionLabel: 'Add bed',
                    onAction: () => _openBedForm(),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                    itemCount: beds.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final bed = beds[index];
                      final tenant = widget.store.people
                          .where((p) => p.id == bed.tenantId);
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              bed.isOccupied ? Icons.person : Icons.bed_outlined,
                            ),
                          ),
                          title: Text(bed.label),
                          subtitle: Text(
                            '${formatMoneyShort(bed.monthlyRent)}/month · '
                            '${bed.isOccupied ? 'Occupied by ${tenant.first.name}' : 'Vacant'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit bed',
                                onPressed: () => _openBedForm(existing: bed),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Delete bed',
                                onPressed: () => _deleteBed(bed),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
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
          : widget.existing!.monthlyRent.toStringAsFixed(0),
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
        monthlyRent: rent ?? 0,
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
                prefixText: 'Rs. ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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