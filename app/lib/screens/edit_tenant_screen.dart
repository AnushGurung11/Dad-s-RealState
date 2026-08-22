import 'package:flutter/material.dart';

import '../services/store_scope.dart';
import '../services/tenant_photo_picker.dart';
import '../widgets/person_avatar.dart';

/// Edit a tenant's personal details — same field set as Add tenant plus
/// monthlyRent/deposit WHEN currently assigned. Editing never touches
/// bedId/status: bed changes go through Assign, leaving goes through the
/// absconded / end-tenure flows.
class EditTenantScreen extends StatefulWidget {
  const EditTenantScreen({
    super.key,
    required this.personId,
    this.photoPicker,
  });

  final String personId;
  final TenantPhotoPicker? photoPicker;

  @override
  State<EditTenantScreen> createState() => _EditTenantScreenState();
}

class _EditTenantScreenState extends State<EditTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _othersController = TextEditingController();
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();

  TenantPhotoPicker? _photoPicker;
  late String? _photoPath;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final person = StoreScope.of(context)
        .people
        .where((p) => p.id == widget.personId)
        .firstOrNull;
    if (person == null) return;
    _nameController.text = person.name;
    _contactController.text = person.contact;
    _workplaceController.text = person.workplaceOrInfo ?? '';
    _othersController.text = person.others ?? '';
    _rentController.text =
        person.monthlyRent == null ? '' : '${person.monthlyRent}';
    _depositController.text =
        person.depositAmount == null ? '' : '${person.depositAmount}';
    _photoPath = person.photoPath;
    _photoPicker ??=
        widget.photoPicker ?? const GalleryTenantPhotoPicker();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _workplaceController.dispose();
    _othersController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _onPickPhoto() async {
    try {
      final stored = await _photoPicker!.pickAndStore();
      if (!mounted || stored == null) return;
      setState(() => _photoPath = stored);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Could not load that photo.')));
    }
  }

  double? _parseMoney(String raw) {
    final value = double.tryParse(raw.trim().replaceAll(',', ''));
    return (value == null || value < 0) ? null : value;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final store = StoreScope.of(context);
    final person =
        store.people.where((p) => p.id == widget.personId).firstOrNull;
    if (person == null) return;
    final assigned = person.bedId != null;

    store.upsertPerson(person.copyWith(
      name: _nameController.text.trim(),
      contact: _contactController.text.trim(),
      workplaceOrInfo: _workplaceController.text.trim(),
      others: _othersController.text.trim(),
      photoPath: _photoPath,
      // Only meaningful while assigned; unassigned people keep theirs blank.
      monthlyRent:
          assigned ? (_parseMoney(_rentController.text) ?? 0) : null,
      depositAmount:
          assigned ? (_parseMoney(_depositController.text) ?? 0) : null,
    ));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Tenant updated')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final person = StoreScope.of(context)
        .people
        .where((p) => p.id == widget.personId)
        .firstOrNull;
    if (person == null) {
      return const Scaffold(body: Center(child: Text('Tenant not found.')));
    }
    final assigned = person.bedId != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit tenant')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  PersonAvatar(
                    photoPath: _photoPath,
                    name: _nameController.text,
                    radius: 36,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('edit_tenant_photo_button'),
                    onPressed: _onPickPhoto,
                    icon: const Icon(Icons.photo_outlined),
                    label: const Text('Change photo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactController,
              decoration: const InputDecoration(
                labelText: 'Contact',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _workplaceController,
              decoration: const InputDecoration(
                labelText: 'Workplace / info',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _othersController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            if (assigned) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _rentController,
                decoration: const InputDecoration(
                  labelText: 'Monthly rent (AED)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) =>
                    _parseMoney(value ?? '') == null ? 'Enter a valid amount' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _depositController,
                decoration: const InputDecoration(
                  labelText: 'Deposit (AED)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) =>
                    _parseMoney(value ?? '') == null ? 'Enter a valid amount' : null,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('save_edit_tenant_button'),
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
