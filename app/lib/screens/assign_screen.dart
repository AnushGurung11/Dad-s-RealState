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

/// Tenants → Assign. Multi-step flow:
/// Step 1: Pick flat + bed + tenant
/// Step 2: Tenure + rent + deposit
/// Then redirects to the flat detail page.
class AssignScreen extends StatefulWidget {
  const AssignScreen({super.key, this.initialBedId});

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
  int _currentStep = 0; // 0 = bed selection, 1 = tenure/rent

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

  bool get _canGoNext => _flatId != null && _bedId != null && _personId != null;

  void _goToStep2() {
    if (!_canGoNext) return;
    setState(() => _currentStep = 1);
  }

  void _goBackToStep1() {
    setState(() => _currentStep = 0);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final service = _assignmentService;
    if (service == null || _personId == null || _bedId == null) return;

    try {
      final store = StoreScope.of(context);
      final flatId = _flatId;
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
      // Redirect to the flat detail page
      if (flatId != null) {
        Navigator.pushReplacementNamed(
          context,
          Routes.flatDetail,
          arguments: flatId,
        );
      } else {
        Navigator.pop(context);
      }
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
    if (_flatId != null && !flatsWithVacancy.any((f) => f.id == _flatId)) {
      _flatId = null;
      _bedId = null;
    }
    final beds = _vacantBedsIn(_flatId);
    if (_bedId != null && !beds.any((b) => b.id == _bedId)) {
      _bedId = null;
    }
    final unassigned = _unassignedPeople();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Step indicator
          Row(
            children: [
              _StepIndicator(
                step: 1,
                label: 'Bed & Tenant',
                isActive: _currentStep == 0,
                isCompleted: _currentStep == 1,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: _currentStep == 1
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
              _StepIndicator(
                step: 2,
                label: 'Tenure & Rent',
                isActive: _currentStep == 1,
                isCompleted: false,
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (_currentStep == 0) ...[
            // Step 1: Bed & Tenant selection
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      key: const Key('assign_flat_picker'),
                      initialValue: _flatId,
                      decoration: InputDecoration(
                        labelText: 'Flat (only flats with vacant beds)',
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
                    DropdownButtonFormField<String>(
                      key: const Key('assign_bed_picker'),
                      initialValue: _bedId,
                      decoration: InputDecoration(
                        labelText: 'Vacant bed',
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: const Key('assign_person_picker'),
                            initialValue: _personId,
                            decoration: InputDecoration(
                              labelText: 'Unassigned tenant',
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('assign_next_button'),
                onPressed: _canGoNext ? _goToStep2 : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B9E3E),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Next'),
              ),
            ),
          ] else ...[
            // Step 2: Tenure & Rent
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Tenure & rent',
                        style: Theme.of(context).textTheme.titleSmall),
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
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('assign_back_button'),
                    onPressed: _goBackToStep1,
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('assign_submit'),
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1B9E3E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Assign tenant'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.step,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  final int step;
  final String label;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? cs.primary
                : isActive
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
            border: Border.all(
              color: isCompleted || isActive ? cs.primary : cs.outline,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 16, color: cs.onPrimary)
                : Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
