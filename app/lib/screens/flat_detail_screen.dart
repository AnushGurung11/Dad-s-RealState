import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../models/bed.dart';
import '../models/flat.dart';
import '../models/person.dart';
import '../services/payment_service.dart';
import '../services/store_scope.dart';
import '../utils/format.dart';
import '../widgets/bed_row.dart';

/// Flat detail: two tabs. "Beds" (default) lists every bed with its occupancy
/// state; "Lease info" shows the contract fields read-only with an edit action.
class FlatDetailScreen extends StatefulWidget {
  const FlatDetailScreen({super.key, required this.flatId});

  final String flatId;

  @override
  State<FlatDetailScreen> createState() => _FlatDetailScreenState();
}

class _FlatDetailScreenState extends State<FlatDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<Bed> _bedsFor(List<Bed> beds) {
    final flatBeds =
        beds.where((b) => b.flatId == widget.flatId).toList(growable: false);
    flatBeds.sort((a, b) => a.label.compareTo(b.label));
    return flatBeds;
  }

  Person? _personFor(List<Person> people, String? id) =>
      id == null ? null : people.where((p) => p.id == id).firstOrNull;

  Future<void> _openLeaseEditor() async {
    final store = StoreScope.of(context);
    final flat =
        store.flats.where((f) => f.id == widget.flatId).firstOrNull;
    if (flat == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _LeaseEditScreen(flat: flat),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final flat =
        store.flats.where((f) => f.id == widget.flatId).firstOrNull;
    if (flat == null) {
      return const Scaffold(body: Center(child: Text('Flat not found.')));
    }

    final now = DateTime.now();
    final overdueIds = PaymentService.overdueTenants(
      payments: store.payments,
      people: store.people,
      month: monthKey(now),
    ).map((p) => p.id).toSet();

    final beds = _bedsFor(store.beds);

    return Scaffold(
      appBar: AppBar(
        title: Text(flat.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Beds'),
            Tab(text: 'Lease info'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: beds.length,
            itemBuilder: (context, index) {
              final bed = beds[index];
              final occupant = _personFor(store.people, bed.tenantId);
              return BedRow(
                key: ValueKey(bed.id),
                bed: bed,
                occupantName: occupant?.name,
                isOverdue:
                    occupant != null && overdueIds.contains(occupant.id),
                onTap: () {},
              );
            },
          ),
          _LeaseInfoTab(flat: flat, onEdit: _openLeaseEditor),
        ],
      ),
    );
  }
}

class _LeaseInfoTab extends StatelessWidget {
  const _LeaseInfoTab({required this.flat, required this.onEdit});

  final Flat flat;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    String? dateText(DateTime? date) => date == null
        ? null
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _LeaseField(label: 'Address', value: flat.address),
        _LeaseField(label: 'Contract date', value: dateText(flat.contractDate)),
        _LeaseField(label: 'Contract person', value: flat.contractPerson),
        _LeaseField(
          label: 'Yearly rent',
          value: flat.yearlyRent == null
              ? null
              : formatMoneyShort(flat.yearlyRent!),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit lease info'),
        ),
      ],
    );
  }
}

class _LeaseField extends StatelessWidget {
  const _LeaseField({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            (value == null || value!.isEmpty) ? '—' : value!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Edit form for the lease fields. Persists through the store on save.
class _LeaseEditScreen extends StatefulWidget {
  const _LeaseEditScreen({required this.flat});

  final Flat flat;

  @override
  State<_LeaseEditScreen> createState() => _LeaseEditScreenState();
}

class _LeaseEditScreenState extends State<_LeaseEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _addressController =
      TextEditingController(text: widget.flat.address);
  late final _contractPersonController =
      TextEditingController(text: widget.flat.contractPerson ?? '');
  late final _yearlyRentController =
      TextEditingController(text: formatMoney(widget.flat.yearlyRent ?? 0));
  late DateTime? _contractDate = widget.flat.contractDate;

  double? _parseMoney(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', ''));
    return (value == null || value < 0) ? null : value;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _contractPersonController.dispose();
    _yearlyRentController.dispose();
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

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    StoreScope.of(context).upsertFlat(
      widget.flat.copyWith(
        address: _addressController.text.trim(),
        contractDate: _contractDate,
        contractPerson: _contractPersonController.text.trim(),
        yearlyRent: _parseMoney(_yearlyRentController.text),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit lease info')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _addressController,
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
                IconButton(
                  tooltip: 'Clear contract date',
                  onPressed: () => setState(() => _contractDate = null),
                  icon: const Icon(Icons.clear),
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
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearlyRentController,
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
                  _parseMoney(value ?? '') == null ? 'Enter a valid amount' : null,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
