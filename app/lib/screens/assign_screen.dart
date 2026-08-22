import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../models/bed.dart';
import '../models/flat.dart';
import '../models/person.dart';
import '../navigation/routes.dart';
import '../services/assignment_service.dart';
import '../services/store_scope.dart';
import '../services/tenure_service.dart';
import '../theme/flat_color.dart';
import '../utils/format.dart';

/// Tenants → Assign. A strictly ordered flow: pick the Flat first (only
/// flats with at least one vacant bed are offered), then a vacant Bed within
/// it, then an unassigned Person (or jump straight to Add tenant), then the
/// tenure + money fields.
class AssignScreen extends StatefulWidget {
  const AssignScreen({super.key, this.initialBedId});

  /// Pre-selects this vacant bed AND its flat (used when arriving from a
  /// tapped vacant bed on a Beds tab).
  final String? initialBedId;

  @override
  State<AssignScreen> createState() => _AssignScreenState();
}

class _AssignScreenState extends State<AssignScreen> {
  final _formKey = GlobalKey<FormState>();
  final _stayMonthsController = TextEditingController(text: '12');
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();

  String? _flatId;
  String? _personId;
  String? _bedId;
  DateTime _joinDate = DateTime.now();
  AssignmentService? _assignmentService;
  bool _initializedFromBed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _assignmentService ??= AssignmentService(StoreScope.of(context));
    if (!_initializedFromBed) {
      _initializedFromBed = true;
      final bed = StoreScope.of(context)
          .beds
          .where((b) => b.id == widget.initialBedId)
          .firstOrNull;
      if (bed != null && !bed.isOccupied) {
        _flatId = bed.flatId;
        _bedId = bed.id;
        _rentController.text = formatMoney(bed.defaultMonthlyRent);
      }
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

  List<Flat> _flatsWithVacantBeds() {
    final store = StoreScope.of(context);
    final flatIdsWithVacancy =
        store.beds.where((b) => !b.isOccupied).map((b) => b.flatId).toSet();
    return store.flats
        .where((f) =>
            !f.archived && flatIdsWithVacancy.contains(f.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<Bed> _vacantBedsIn(String? flatId) {
    if (flatId == null) return const [];
    return StoreScope.of(context)
        .beds
        .where((b) => b.flatId == flatId && !b.isOccupied)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
  }

  List<Person> _unassignedPeople() {
    return StoreScope.of(context)
        .people
        .where((p) => p.bedId == null && p.status == PersonStatus.active)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
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

  void _onFlatSelected(String? flatId) {
    setState(() {
      _flatId = flatId;
      // Changing flats invalidates the bed picked inside the previous one.
      _bedId = null;
    });
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

  Future<void> _openAddTenant() async {
    await Navigator.pushNamed(context, Routes.tenantsAdd);
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final flatsWithVacancy = _flatsWithVacantBeds();
    final beds = _vacantBedsIn(_flatId);
    final unassigned = _unassignedPeople();

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
                  // Step 1 — pick a flat that still has vacancy.
                  DropdownButtonFormField<String>(
                    key: const Key('assign_flat_picker'),
                    initialValue: _flatId,
                    decoration: InputDecoration(
                      labelText:
                          'Step 1 · Flat (only flats with vacant beds)',
                      border: const OutlineInputBorder(),
                      helperText: flatsWithVacancy.isEmpty
                          ? 'No flat has a vacant bed'
                          : '${flatsWithVacancy.length} flat(s) available',
                    ),
                    hint: const Text('Select flat'),
                    items: flatsWithVacancy
                        .map(
                          (f) => DropdownMenuItem(
                            value: f.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: flatColorFor(f.id),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(f.name),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _onFlatSelected,
                    validator: (value) => value == null ? 'Pick a flat' : null,
                  ),
                  const SizedBox(height: 12),
                  // Step 2 — pick a vacant bed inside the chosen flat.
                  DropdownButtonFormField<String>(
                    key: const Key('assign_bed_picker'),
                    initialValue: _bedId,
                    decoration: InputDecoration(
                      labelText: 'Step 2 · Vacant bed',
                      border: const OutlineInputBorder(),
                      helperText: _flatId == null
                          ? 'Pick a flat first'
                          : '${beds.length} vacant bed(s)',
                    ),
                    hint: const Text('Select bed'),
                    items: beds
                        .map(
                          (bed) => DropdownMenuItem(
                            value: bed.id,
                            child: Row(
                              children: [
                                Container(
                                  key: ValueKey('bed-dot-${bed.id}'),
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: flatColorFor(bed.flatId),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                    '${bed.label} · ${formatMoneyShort(bed.defaultMonthlyRent)}'),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _flatId == null ? null : _onBedSelected,
                    validator: (value) => value == null ? 'Pick a bed' : null,
                  ),
                  const SizedBox(height: 12),
                  // Step 3 — pick an unassigned person, or add one.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: const Key('assign_person_picker'),
                          initialValue: _personId,
                          decoration: InputDecoration(
                            labelText: 'Step 3 · Unassigned tenant',
                            border: const OutlineInputBorder(),
                            helperText: unassigned.isEmpty
                                ? 'No unassigned tenants yet'
                                : '${unassigned.length} waiting',
                          ),
                          hint: const Text('Select tenant'),
                          items: unassigned
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
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('assign_add_tenant_link'),
                      onPressed: _openAddTenant,
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: Text(unassigned.isEmpty
                          ? 'No one to assign — add a tenant first'
                          : 'Add another tenant'),
                    ),
                  ),
                  const Divider(height: 24),
                  // Step 4 — tenure + money.
                  Text('Step 4 · Tenure & rent',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
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
                    key: const Key('assign_submit'),
                    onPressed: _save,
                    icon: const Icon(Icons.link),
                    label: const Text('Assign tenant'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
