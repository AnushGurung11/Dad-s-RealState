import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../models/flat.dart';
import '../navigation/routes.dart';
import '../services/bed_capacity_service.dart';
import '../services/flat_creation_service.dart';
import '../services/store_scope.dart';

/// Flats grid — the brief view. Each card shows only the flat name and its
/// occupancy count; tapping opens the detail screen.
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

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final flats = store.flats;
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
            FilledButton.icon(
              onPressed: _openCreateForm,
              icon: const Icon(Icons.add),
              label: const Text('Add flat'),
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
            flat: flat,
            occupiedBeds: occupied,
            totalBeds: flatBeds.length,
            onTap: () => _openDetail(flat),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add),
        label: const Text('Add flat'),
      ),
    );
  }
}

class _FlatCard extends StatelessWidget {
  const _FlatCard({
    required this.flat,
    required this.occupiedBeds,
    required this.totalBeds,
    required this.onTap,
  });

  final Flat flat;
  final int occupiedBeds;
  final int totalBeds;
  final VoidCallback onTap;

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
              Text(
                flat.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

/// Full-screen flat creation form. On save, [FlatCreationService] creates the
/// flat, its N beds and the lease cheque setting in one atomic write.
class FlatCreateScreen extends StatefulWidget {
  const FlatCreateScreen({super.key});

  @override
  State<FlatCreateScreen> createState() => _FlatCreateScreenState();
}

class _FlatCreateScreenState extends State<FlatCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  FlatCreationService? _service;

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contractPersonController = TextEditingController();
  final _yearlyRentController = TextEditingController();
  final _bedCountController = TextEditingController(text: '5');
  final _defaultRentController = TextEditingController();
  DateTime? _contractDate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service ??= FlatCreationService(StoreScope.of(context));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contractPersonController.dispose();
    _yearlyRentController.dispose();
    _bedCountController.dispose();
    _defaultRentController.dispose();
    super.dispose();
  }

  Future<void> _pickContractDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _contractDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _contractDate = picked);
  }

  double? _parseMoney(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', ''));
    return (value == null || value < 0) ? null : value;
  }

  int? _parseBedCount(String raw) {
    final value = int.tryParse(raw.trim());
    return BedCapacityService.canCreateFlat(value ?? 0) ? value : null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final service = _service;
    if (service == null) return;

    try {
      service.createFlat(
        name: _nameController.text,
        address: _addressController.text,
        contractDate: _contractDate,
        contractPerson: _contractPersonController.text,
        yearlyRent: _parseMoney(_yearlyRentController.text)!,
        bedCount: _parseBedCount(_bedCountController.text)!,
        defaultRentPerBed: _parseMoney(_defaultRentController.text)!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${_nameController.text.trim()} created')));
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
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
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
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickContractDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _contractDate == null
                          ? 'Contract date'
                          : '${_contractDate!.year}-'
                              '${_contractDate!.month.toString().padLeft(2, '0')}-'
                              '${_contractDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contractPersonController,
              decoration: const InputDecoration(
                labelText: 'Contract person',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearlyRentController,
              decoration: InputDecoration(
                labelText: 'Yearly rent (${AppConfig.currencySymbol})',
                border: const OutlineInputBorder(),
                helperText:
                    'Lease cheque auto-calculated as yearly rent ÷ '
                    '${FlatCreationService.chequesPerYear}',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
              ],
              textInputAction: TextInputAction.next,
              validator: (value) =>
                  _parseMoney(value ?? '') == null ? 'Enter a valid amount' : null,
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
                  _parseMoney(value ?? '') == null ? 'Enter a valid amount' : null,
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
