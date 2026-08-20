import 'package:flutter/material.dart';

import '../models/bed.dart';
import '../models/flat.dart';
import '../models/lease_cheque_setting.dart';
import '../services/bed_capacity_service.dart';
import '../services/json_store.dart';
import '../utils/ids.dart';
import '../widgets/empty_state.dart';
import 'flat_detail_screen.dart';

class FlatsScreen extends StatefulWidget {
  const FlatsScreen({super.key, required this.store});

  final JsonStore store;

  @override
  State<FlatsScreen> createState() => _FlatsScreenState();
}

class _FlatsScreenState extends State<FlatsScreen> {
  Future<void> _openFlatForm({Flat? existing}) async {
    final result = await showModalBottomSheet<({Flat flat, int bedCount})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FlatForm(existing: existing),
    );
    if (result == null) return;
    setState(() {
      final previous = widget.store.flats
          .where((f) => f.id == result.flat.id)
          .firstOrNull;
      widget.store.upsertFlat(result.flat);

      if (existing == null) {
        for (var i = 1; i <= result.bedCount; i++) {
          widget.store.upsertBed(
            Bed(
              id: '${newId()}-$i',
              flatId: result.flat.id,
              label: 'Bed $i',
              defaultMonthlyRent: 0,
            ),
          );
        }
        final now = DateTime.now();
        final yearlyRent = result.flat.yearlyRent;
        widget.store.upsertChequeSetting(
          LeaseChequeSetting(
            id: newId(),
            flatId: result.flat.id,
            ownerName: result.flat.contractPerson ?? '',
            amount: yearlyRent == null ? 0 : yearlyRent / 6,
            nextDueDate: DateTime(now.year, now.month + 2, now.day),
          ),
        );
      } else if (previous != null &&
          result.flat.yearlyRent != previous.yearlyRent &&
          result.flat.yearlyRent != null) {
        // Cheque amount auto-tracks the yearly rent (6 cheques per year).
        final setting = widget.store.leaseChequeSettings
            .where((s) => s.flatId == result.flat.id)
            .firstOrNull;
        if (setting != null) {
          widget.store.upsertChequeSetting(
            setting.copyWith(amount: result.flat.yearlyRent! / 6),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final flats = widget.store.flats;
    return Scaffold(
      appBar: AppBar(title: const Text('Flats')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'flats-fab',
        onPressed: () => _openFlatForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add flat'),
      ),
      body: flats.isEmpty
          ? EmptyState(
              icon: Icons.apartment,
              message: 'No flats yet. Add your first flat to start tracking beds.',
              actionLabel: 'Add flat',
              onAction: () => _openFlatForm(),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: flats.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final flat = flats[index];
                final beds = widget.store.beds.where((b) => b.flatId == flat.id);
                final occupied = beds.where((b) => b.tenantId != null).length;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: const Icon(Icons.apartment),
                    ),
                    title: Text(flat.name),
                    subtitle: Text('$occupied / ${beds.length} beds'),
                    trailing: _ChequeBadge(
                      setting: widget.store.leaseChequeSettings
                          .where((s) => s.flatId == flat.id)
                          .firstOrNull,
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FlatDetailScreen(
                            store: widget.store,
                            flat: flat,
                          ),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _ChequeBadge extends StatelessWidget {
  const _ChequeBadge({this.setting});

  final LeaseChequeSetting? setting;

  @override
  Widget build(BuildContext context) {
    final setting = this.setting;
    if (setting == null || setting.amount <= 0) return const SizedBox.shrink();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = setting.nextDueDate;
    final dueDay = DateTime(due.year, due.month, due.day);
    final daysLeft = dueDay.difference(today).inDays;
    if (daysLeft < 0 || daysLeft > 3) return const SizedBox.shrink();

    final urgent = daysLeft == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: urgent
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Cheque in ${daysLeft}d',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: urgent
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : Theme.of(context).colorScheme.onTertiaryContainer,
            ),
      ),
    );
  }
}

class _FlatForm extends StatefulWidget {
  const _FlatForm({this.existing});

  final Flat? existing;

  @override
  State<_FlatForm> createState() => _FlatFormState();
}

class _FlatFormState extends State<_FlatForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _beds;
  late final TextEditingController _contractPerson;
  late final TextEditingController _yearlyRent;
  DateTime? _contractDate;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _address = TextEditingController(text: widget.existing?.address ?? '');
    _beds = TextEditingController(text: widget.existing == null ? '5' : '');
    _contractPerson =
        TextEditingController(text: widget.existing?.contractPerson ?? '');
    _yearlyRent = TextEditingController(
      text: widget.existing?.yearlyRent == null
          ? ''
          : widget.existing!.yearlyRent!.toStringAsFixed(0),
    );
    _contractDate = widget.existing?.contractDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _beds.dispose();
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
    final existing = widget.existing;
    final bedCount = int.tryParse(_beds.text.trim()) ?? 0;
    final yearlyRent = double.tryParse(_yearlyRent.text.trim());
    Navigator.of(context).pop(
      (
        flat: Flat(
          id: existing?.id ?? newId(),
          name: _name.text.trim(),
          address: _address.text.trim(),
          createdAt: existing?.createdAt ?? DateTime.now(),
          contractDate: _contractDate,
          contractPerson:
              _contractPerson.text.trim().isEmpty ? null : _contractPerson.text.trim(),
          yearlyRent: yearlyRent,
        ),
        bedCount: bedCount,
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
                widget.existing == null ? 'Add flat' : 'Edit flat',
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
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
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
              if (widget.existing == null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _beds,
                  decoration: const InputDecoration(
                    labelText: 'Number of beds',
                    helperText: 'A flat must have ${BedCapacityService.minBeds}-'
                        '${BedCapacityService.maxBeds} beds.',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final parsed = int.tryParse(v?.trim() ?? '');
                    if (parsed == null) return 'Enter a number';
                    if (!BedCapacityService.canCreateFlat(parsed)) {
                      return 'Beds must be between '
                          '${BedCapacityService.minBeds} and '
                          '${BedCapacityService.maxBeds}';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _contractPerson,
                decoration: const InputDecoration(
                  labelText: 'Contract person',
                  helperText: 'Registered owner of the lease.',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearlyRent,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                child: Text(widget.existing == null ? 'Add' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}