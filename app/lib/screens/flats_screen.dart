import 'package:flutter/material.dart';

import '../models/flat.dart';
import '../services/json_store.dart';
import '../utils/ids.dart';
import '../widgets/confirm_delete_dialog.dart';
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
    final result = await showModalBottomSheet<Flat>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FlatForm(existing: existing),
    );
    if (result == null) return;
    setState(() {
      widget.store.upsertFlat(result);
    });
  }

  Future<void> _deleteFlat(Flat flat) async {
    final beds = widget.store.beds.where((b) => b.flatId == flat.id).toList();
    final occupied = beds.where((b) => b.tenantId != null).length;
    final detail = beds.isEmpty
        ? 'This flat has no beds. Delete it?'
        : 'This flat has ${beds.length} '
            'bed${beds.length == 1 ? '' : 's'} and $occupied active '
            'tenant${occupied == 1 ? '' : 's'} — delete anyway?';
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete ${flat.name}?',
      detail: detail,
    );
    if (!confirmed) return;
    setState(() {
      widget.store.deleteFlat(flat.id);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${flat.name}')),
    );
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
                    subtitle: Text(
                      '${flat.address}\n'
                      '${beds.length} bed${beds.length == 1 ? '' : 's'} · '
                      '$occupied occupied',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit flat',
                          onPressed: () => _openFlatForm(existing: flat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete flat',
                          onPressed: () => _deleteFlat(flat),
                        ),
                      ],
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

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _address = TextEditingController(text: widget.existing?.address ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existing;
    Navigator.of(context).pop(
      Flat(
        id: existing?.id ?? newId(),
        name: _name.text.trim(),
        address: _address.text.trim(),
        createdAt: existing?.createdAt ?? DateTime.now(),
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
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Address is required' : null,
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