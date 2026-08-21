import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../models/bed.dart';
import '../models/flat.dart';
import '../navigation/routes.dart';
import '../services/assignment_service.dart';
import '../services/store_scope.dart';
import '../services/tenure_service.dart';
import '../theme/flat_color.dart';
import '../widgets/grouped_tenant_list.dart';
import '../utils/format.dart';

/// Tenants → Assign. One screen, two sections: the assign form on top and a
/// read-only "currently assigned" list below, both grouped/color-coded by
/// flat via [flatColorFor].
class AssignScreen extends StatefulWidget {
  const AssignScreen({super.key, this.initialBedId});

  /// Pre-selects this vacant bed (used when arriving from a tapped vacant bed
  /// on the Beds tab).
  final String? initialBedId;

  @override
  State<AssignScreen> createState() => _AssignScreenState();
}

class _AssignScreenState extends State<AssignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _stayMonthsController = TextEditingController(text: '12');
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();

  String? _personId;
  String? _bedId;
  DateTime _joinDate = DateTime.now();
  AssignmentService? _assignmentService;

  @override
  void initState() {
    super.initState();
    _bedId = widget.initialBedId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _assignmentService ??= AssignmentService(StoreScope.of(context));
    // Pre-fill rent once the store is available for an initial bed selection.
    if (_rentController.text.isEmpty && _bedId != null) {
      final bed =
          StoreScope.of(context).beds.where((b) => b.id == _bedId).firstOrNull;
      if (bed != null) _rentController.text = formatMoney(bed.defaultMonthlyRent);
    }
  }

  @override
  void dispose() {
    _stayMonthsController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<Flat> _flatsWith(List<Bed> beds, bool Function(Bed) predicate) {
    final flatIds = beds.where(predicate).map((b) => b.flatId).toSet().toList();
    return StoreScope.of(context)
        .flats
        .where((f) => flatIds.contains(f.id))
        .toList();
  }

  Future<void> _pickJoinDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate,
      firstDate: DateTime(_joinDate.year - 5),
      lastDate: DateTime(_joinDate.year + 5),
    );
    if (picked != null) setState(() => _joinDate = picked);
  }

  void _onBedSelected(String? bedId) {
    setState(() => _bedId = bedId);
    if (bedId == null) return;
    final bed = StoreScope.of(context)
        .beds
        .where((b) => b.id == bedId)
        .firstOrNull;
    if (bed != null) {
      _rentController.text = formatMoney(bed.defaultMonthlyRent);
    }
  }

  int? _parseMonths(String raw) {
    final value = int.tryParse(raw.trim());
    return (value == null || value < 1) ? null : value;
  }

  double? _parseMoney(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', ''));
    return (value == null || value <= 0) ? null : value;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final service = _assignmentService;
    if (service == null || _personId == null || _bedId == null) return;

    try {
      final store = StoreScope.of(context);
      service.assignTenant(
        bed: store.beds.singleWhere((b) => b.id == _bedId),
        person: store.people.singleWhere((p) => p.id == _personId),
        deposit: _parseMoney(_depositController.text)!,
        joinDate: _joinDate,
        plannedStayMonths: _parseMonths(_stayMonthsController.text)!,
        monthlyRent: _parseMoney(_rentController.text),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Tenant assigned')));
      setState(() {
        _personId = null;
        _bedId = null;
        _stayMonthsController.text = '12';
        _rentController.clear();
        _depositController.clear();
      });
    } on AssignmentException catch (error) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openAddMember() async {
    await Navigator.pushNamed(context, Routes.tenantsAdd);
    if (mounted) _refresh();
  }

  Future<void> _openPersonDetail(String personId) async {
    await Navigator.pushNamed(context, Routes.tenantsDetail,
        arguments: personId);
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final unassignedPeople = store.people
        .where((p) => p.bedId == null && !p.archived)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final vacantBeds =
        store.beds.where((b) => !b.isOccupied).toList(growable: false);
    final occupiedBeds =
        store.beds.where((b) => b.isOccupied).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Form(
          key: _formKey,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _personId,
                          decoration: const InputDecoration(
                            labelText: 'Tenant',
                            border: OutlineInputBorder(),
                          ),
                          hint: const Text('Select tenant'),
                          items: unassignedPeople
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _personId = value),
                          validator: (value) =>
                              value == null ? 'Pick a tenant' : null,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add member',
                        onPressed: _openAddMember,
                        icon: const Icon(Icons.person_add_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _bedId,
                    decoration: const InputDecoration(
                      labelText: 'Vacant bed',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select bed'),
                    items: _bedPickerItems(vacantBeds),
                    onChanged: _onBedSelected,
                    validator: (value) => value == null ? 'Pick a bed' : null,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickJoinDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      'Join date: ${_joinDate.year}-'
                      '${_joinDate.month.toString().padLeft(2, '0')}-'
                      '${_joinDate.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stayMonthsController,
                    decoration: const InputDecoration(
                      labelText: 'Planned stay (months)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _refresh(),
                    validator: (value) =>
                        _parseMonths(value ?? '') == null ? 'Min. 1' : null,
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _stayMonthsController,
                    builder: (context, value, _) {
                      final months = _parseMonths(value.text);
                      if (months == null) return const SizedBox.shrink();
                      final leave =
                          TenureService.computedLeaveDate(_joinDate, months);
                      return Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          'Leaves ${leave.year}-${leave.month.toString().padLeft(2, '0')}-${leave.day.toString().padLeft(2, '0')}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _rentController,
                    decoration: InputDecoration(
                      labelText: 'Monthly rent (${AppConfig.currencySymbol})',
                      helperText: 'Pre-filled from the bed, editable',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
                    ],
                    textInputAction: TextInputAction.next,
                    validator: (value) => (_parseMoney(value ?? '') == null)
                        ? 'Enter a valid amount'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _depositController,
                    decoration: InputDecoration(
                      labelText: 'Deposit (${AppConfig.currencySymbol})',
                      helperText: 'Required, counts as income',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
                    ],
                    validator: (value) => (_parseMoney(value ?? '') == null)
                        ? 'Deposit must be greater than 0'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.link),
                    label: const Text('Assign tenant'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Currently assigned', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (occupiedBeds.isEmpty)
          Text(
            'No one is assigned yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else
          GroupedTenantList(
            beds: occupiedBeds,
            onPersonTap: (person) => _openPersonDetail(person.id),
          ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _bedPickerItems(List<Bed> vacantBeds) {
    final items = <DropdownMenuItem<String>>[];
    for (final flat in _flatsWith(vacantBeds, (b) => true)) {
      items.add(
        DropdownMenuItem(
          enabled: false,
          child: Text(
            flat.name,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
      for (final bed in vacantBeds.where((b) => b.flatId == flat.id)) {
        items.add(
          DropdownMenuItem(
            value: bed.id,
            child: Row(
              children: [
                Container(
                  key: ValueKey('bed-dot-${bed.id}'),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: flatColorFor(flat.id),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(bed.label),
              ],
            ),
          ),
        );
      }
    }
    return items;
  }
}
