import 'package:flutter/material.dart';

import '../models/person.dart';
import '../services/store_scope.dart';
import '../services/tenant_photo_picker.dart';
import '../utils/ids.dart';
import '../widgets/person_avatar.dart';

/// Tenants → Add tenant. Creates an UNASSIGNED person — no bed, no rent and
/// no deposit yet (those are captured at assignment). The picked photo is
/// copied into the app's documents directory so the stored path stays stable;
/// the OS picker's transient path is never persisted.
class AddTenantScreen extends StatefulWidget {
  const AddTenantScreen({super.key, this.photoPicker});

  /// Injectable for tests; defaults to the real gallery picker + file copy.
  final TenantPhotoPicker? photoPicker;

  @override
  State<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends State<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _othersController = TextEditingController();

  TenantPhotoPicker? _photoPicker;
  String? _pendingPhotoPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _photoPicker ??=
        widget.photoPicker ?? const GalleryTenantPhotoPicker();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _workplaceController.dispose();
    _othersController.dispose();
    super.dispose();
  }

  Future<void> _onPickPhoto() async {
    try {
      final stored = await _photoPicker!.pickAndStore();
      if (!mounted) return;
      if (stored == null) return;
      setState(() => _pendingPhotoPath = stored);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Could not load that photo.')));
    }
  }  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    StoreScope.of(context).upsertPerson(
      Person(
        id: newId(),
        name: _nameController.text.trim(),
        contact: _contactController.text.trim(),
        workplaceOrInfo: _workplaceController.text.trim(),
        others: _othersController.text.trim(),
        photoPath: _pendingPhotoPath,
      ),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text('${_nameController.text.trim()} added')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add tenant')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  PersonAvatar(
                    photoPath: _pendingPhotoPath,
                    name: _nameController.text,
                    radius: 36,
                    key: ValueKey('avatar-${_pendingPhotoPath ?? 'none'}'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('add_tenant_photo_button'),
                    onPressed: _onPickPhoto,
                    icon: const Icon(Icons.photo_outlined),
                    label: Text(_pendingPhotoPath == null
                        ? 'Add photo'
                        : 'Change photo'),
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
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
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
              textInputAction: TextInputAction.next,
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
              textInputAction: TextInputAction.next,
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
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('save_tenant_button'),
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save tenant'),
            ),
          ],
        ),
      ),
    );
  }
}

