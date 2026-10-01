import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/legal_document.dart';
import '../services/flat_legal_doc_service.dart';
import '../services/store_scope.dart';
import '../widgets/empty_state.dart';

/// Every scanned document attached to one flat, as a two-column thumbnail
/// grid. Tapping a thumbnail opens a zoomable full-screen viewer; the pencil
/// and trash buttons under it edit the label/description or delete that single
/// document.
class FlatLegalDocsScreen extends StatefulWidget {
  const FlatLegalDocsScreen({
    super.key,
    required this.flatId,
    required this.flatName,
  });

  final String flatId;
  final String flatName;

  @override
  State<FlatLegalDocsScreen> createState() => _FlatLegalDocsScreenState();
}

class _FlatLegalDocsScreenState extends State<FlatLegalDocsScreen> {
  void _refresh() => setState(() {});

  Future<void> _openViewer(BuildContext context, LegalDocument doc) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => _LegalDocViewer(doc: doc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final docs = store.getLegalDocumentsForFlat(widget.flatId);

    return Scaffold(
      appBar: AppBar(title: Text('${widget.flatName} - Legal Docs')),
      body: docs.isEmpty
          ? const EmptyState(
              icon: Icons.gavel,
              message: 'No legal documents yet',
            )
          : GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              childAspectRatio: 0.75,
              children: [
                for (final doc in docs)
                  _LegalDocCard(
                    doc: doc,
                    onOpen: () => _openViewer(context, doc),
                    onEdit: () async {
                      await FlatLegalDocService.editDocument(
                        context: context,
                        store: store,
                        doc: doc,
                      );
                      if (mounted) _refresh();
                    },
                    onDelete: () async {
                      final deleted = await FlatLegalDocService.deleteDocument(
                        context: context,
                        store: store,
                        doc: doc,
                      );
                      if (deleted && mounted) _refresh();
                    },
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await FlatLegalDocService.addDocument(
            context: context,
            store: store,
            flatId: widget.flatId,
          );
          if (added != null && mounted) _refresh();
        },
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Add Document'),
      ),
    );
  }
}

class _LegalDocCard extends StatelessWidget {
  const _LegalDocCard({
    required this.doc,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final LegalDocument doc;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final description = doc.description;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onOpen,
            child: SizedBox(
              height: 120,
              child: Image.file(
                File(doc.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      (description == null || description.isEmpty)
                          ? 'No description'
                          : description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        color: Colors.blue,
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit),
                        onPressed: onEdit,
                      ),
                      IconButton(
                        iconSize: 20,
                        visualDensity: VisualDensity.compact,
                        color: Colors.red,
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete),
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom view of a document image with a share action.
class _LegalDocViewer extends StatelessWidget {
  const _LegalDocViewer({required this.doc});

  final LegalDocument doc;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    doc.label,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share',
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        files: [XFile(doc.imagePath)],
                        text: doc.label,
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Flexible(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Image.file(
                File(doc.imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
          ),
          if (doc.description != null && doc.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                doc.description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
