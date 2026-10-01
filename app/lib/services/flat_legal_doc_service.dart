import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../models/legal_document.dart';
import '../utils/ids.dart';
import 'json_store.dart';

/// Folder (relative to the app documents directory) where every legal document
/// image is copied. Kept next to the other app folders so a backup zip can
/// round-trip it as one unit.
const String kLegalDocsDirName = 'legal_docs';

/// Legal document flows: pick → copy into app storage → collect label /
/// description → write the record. Editing never touches the image; deleting
/// removes the record *and* the file, one document at a time.
abstract final class FlatLegalDocService {
  /// Picks an image, copies it into `<appDocs>/LUCKY/legal_docs/` and saves a
  /// new [LegalDocument]. Returns silently when the user cancels the picker or
  /// leaves the label blank.
  static Future<LegalDocument?> addDocument({
    required BuildContext context,
    required JsonStore store,
    required String flatId,
  }) async {
    final storedPath = await _pickAndStoreImage();
    if (storedPath == null) return null;
    if (!context.mounted) return null;

    final draft = await _showDocumentDialog(
      context,
      title: 'Add Document',
      confirmLabel: 'Save',
      imagePath: storedPath,
    );
    if (draft == null) {
      // Dialog abandoned: the copied image has no record pointing at it, so
      // drop it rather than leaving an orphan in app storage.
      await _deleteFileQuietly(storedPath);
      return null;
    }

    final doc = LegalDocument.createNew(
      flatId: flatId,
      label: draft.label,
      description: draft.description,
      imagePath: storedPath,
    );
    store.upsertLegalDocument(doc);
    return doc;
  }

  /// Edits label and description only. The image is deliberately not re-picked
  /// — the original scan stays on disk and in the record.
  static Future<void> editDocument({
    required BuildContext context,
    required JsonStore store,
    required LegalDocument doc,
  }) async {
    final draft = await _showDocumentDialog(
      context,
      title: 'Edit Document',
      confirmLabel: 'Update',
      imagePath: doc.imagePath,
      initialLabel: doc.label,
      initialDescription: doc.description,
    );
    if (draft == null) return;

    store.upsertLegalDocument(
      doc.copyWith(
        label: draft.label,
        description: draft.description,
        clearDescription: draft.description == null,
      ),
    );
  }

  /// Removes this document only — never a cascade over the flat's other
  /// documents. The JSON record goes first, then the physical file; a missing
  /// or locked file must not leave the record behind, and a failed file delete
  /// must not abort the flow.
  static Future<bool> deleteDocument({
    required BuildContext context,
    required JsonStore store,
    required LegalDocument doc,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${doc.label}"?'),
        content: const Text(
          'The image and its details are removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    store.deleteLegalDocument(doc.id);
    await _deleteFileQuietly(doc.imagePath);
    return true;
  }

  /// Copies the picked image into internal app storage and returns the stored
  /// path, or null when the user cancelled.
  static Future<String?> _pickAndStoreImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final documents = await getApplicationDocumentsDirectory();
    final docsDir = Directory(
      '${documents.path}${Platform.pathSeparator}${AppConfig.appName}'
      '${Platform.pathSeparator}$kLegalDocsDirName',
    );
    if (!docsDir.existsSync()) docsDir.createSync(recursive: true);

    // Always store as .jpg under a generated name: the picked file's own name
    // and extension are not trustworthy and the id keeps names unique.
    final target =
        '${docsDir.path}${Platform.pathSeparator}${newId()}.jpg';
    await File(picked.path).copy(target);
    return target;
  }

  static Future<void> _deleteFileQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A leftover file is harmless; the record is already gone.
    }
  }

  static Future<_DocumentDraft?> _showDocumentDialog(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    required String imagePath,
    String? initialLabel,
    String? initialDescription,
  }) {
    return showDialog<_DocumentDraft>(
      context: context,
      builder: (ctx) => _DocumentDialog(
        title: title,
        confirmLabel: confirmLabel,
        imagePath: imagePath,
        initialLabel: initialLabel,
        initialDescription: initialDescription,
      ),
    );
  }
}

/// The label/description pair a dialog returns, before it becomes a record.
class _DocumentDraft {
  const _DocumentDraft(this.label, this.description);

  final String label;
  final String? description;
}

class _DocumentDialog extends StatefulWidget {
  const _DocumentDialog({
    required this.title,
    required this.confirmLabel,
    required this.imagePath,
    this.initialLabel,
    this.initialDescription,
  });

  final String title;
  final String confirmLabel;
  final String imagePath;
  final String? initialLabel;
  final String? initialDescription;

  @override
  State<_DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends State<_DocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.initialLabel ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final description = _descriptionController.text.trim();
    Navigator.pop(
      context,
      _DocumentDraft(
        _labelController.text.trim(),
        description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 150,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _labelController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Label *',
                  hintText: 'e.g. Lease Contract 2026',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Label is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g. Signed by landlord and tenant',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
