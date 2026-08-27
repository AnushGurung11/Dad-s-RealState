import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../navigation/routes.dart';
import '../services/backup_service.dart';
import '../services/excel_export_service.dart';
import '../services/store_scope.dart';
import '../widgets/lucky_wordmark.dart';

/// Which part of the settings screen to land on.
enum SettingsSection { archive, data }

/// Settings: an Archive section, a Data section (backup/restore/export), and an About block.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.initialSection});

  final SettingsSection? initialSection;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Archive section
        Text('Archive', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            key: const Key('settings_archived_tenants'),
            leading: const Icon(Icons.person_off_outlined),
            title: const Text('Archived Tenants'),
            subtitle:
                const Text('Tenants whose stay ended or who absconded'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, Routes.archiveTenants),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            key: const Key('settings_archive_flats'),
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('Archived Flats'),
            subtitle:
                const Text('Flats retired from the active grid, kept for records'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, Routes.archiveFlats),
          ),
        ),

        // Data section
        const SizedBox(height: 24),
        Text('Data', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _DataSection(),

        // About section
        const SizedBox(height: 24),
        Text('About', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        const Center(child: LuckyWordmark()),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'LUCKY ${AppConfig.currencySymbol} tracker for landlords',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

/// Data section with backup, restore, and export actions.
class _DataSection extends StatefulWidget {
  @override
  State<_DataSection> createState() => _DataSectionState();
}

enum _DataAction { createBackup, restoreBackup, exportExcel }

class _DataSectionState extends State<_DataSection> {
  final Map<_DataAction, bool> _isBusy = {
    _DataAction.createBackup: false,
    _DataAction.restoreBackup: false,
    _DataAction.exportExcel: false,
  };

  bool _isBusyFor(_DataAction action) => _isBusy[action] ?? false;

  void _setBusy(_DataAction action, bool busy) {
    if (mounted) setState(() => _isBusy[action] = busy);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            key: const Key('settings_create_backup'),
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Create backup'),
            subtitle: const Text('Export all data and photos as a zip file'),
            trailing: _isBusyFor(_DataAction.createBackup)
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isBusyFor(_DataAction.createBackup) ? null : _createBackup,
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select the backup file (.zip) — no need to extract it, the app reads it directly.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
              ListTile(
                key: const Key('settings_restore_backup'),
                leading: const Icon(Icons.restore_outlined),
                title: const Text('Restore from backup'),
                subtitle: const Text('Replace all data with a backup zip (destructive)'),
                trailing: _isBusyFor(_DataAction.restoreBackup)
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _isBusyFor(_DataAction.restoreBackup) ? null : _restoreBackup,
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            key: const Key('settings_export_excel'),
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export to Excel'),
            subtitle: const Text('One-way export for viewing (7 sheets, never re-imported)'),
            trailing: _isBusyFor(_DataAction.exportExcel)
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isBusyFor(_DataAction.exportExcel) ? null : _exportExcel,
          ),
        ),
      ],
    );
  }

  Future<void> _createBackup() async {
    _setBusy(_DataAction.createBackup, true);
    try {
      final store = StoreScope.of(context);
      final backupService = BackupService(store);
      final file = await backupService.createBackup();
      if (!mounted) return;
      await _showBackupOptions(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create backup: $e')),
      );
    } finally {
      _setBusy(_DataAction.createBackup, false);
    }
  }

  Future<void> _showBackupOptions(File file) async {
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save),
              title: const Text('Save to device'),
              onTap: () => Navigator.pop(ctx, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'save') {
      await _saveFileToDevice(file);
    } else if (choice == 'share') {
      await Share.shareXFiles([XFile(file.path)], text: 'LUCKY backup');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup created and shared')),
      );
    }
  }

  Future<void> _saveFileToDevice(File file) async {
    try {
      Directory? targetDir;
      if (Platform.isAndroid) {
        // Try to get the Downloads directory on Android
        targetDir = await getExternalStorageDirectory();
        if (targetDir != null) {
          // Navigate to Downloads from the app-specific external storage
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            targetDir = downloadsDir;
          }
        }
      } else if (Platform.isIOS) {
        // On iOS, use the Documents directory
        targetDir = await getApplicationDocumentsDirectory();
      } else {
        // Fallback to app documents directory
        targetDir = await getApplicationDocumentsDirectory();
      }

      if (targetDir == null) {
        targetDir = await getApplicationDocumentsDirectory();
      }

      final fileName = file.path.split('/').last;
      final targetFile = File('${targetDir.path}/$fileName');
      await targetFile.writeAsBytes(await file.readAsBytes(), flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup saved to ${targetFile.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save backup: $e')),
      );
    }
  }

  Future<void> _restoreBackup() async {
    _setBusy(_DataAction.restoreBackup, true);
    try {
      // Pick backup file
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'Select backup zip to restore',
      );
      if (result.isEmpty) {
        return;
      }
      final file = File(result.single.path!);

      // Validate first
      final store = StoreScope.of(context);
      final backupService = BackupService(store);
      final validation = await backupService.validateBackup(file);

      if (!validation.valid) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Invalid Backup'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This backup cannot be restored:'),
                  const SizedBox(height: 12),
                  ...validation.errors!.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $e'),
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Show confirmation with summary
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ Restore Backup?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will REPLACE ALL current data on this device. '
                'This action cannot be undone.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(validation.summary ?? ''),
              const SizedBox(height: 16),
              if (validation.meta != null)
                Text(
                  'Backup created: ${_formatDateTime(validation.meta!.exportedAt)} '
                  '(app v${validation.meta!.appVersion}, schema v${validation.meta!.schemaVersion})',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              const SizedBox(height: 16),
              const Text('Type "REPLACE" to confirm:'),
              const SizedBox(height: 8),
              _ConfirmationTextField(onConfirmed: (confirmed) {
                Navigator.pop(ctx, confirmed);
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Perform restore
      await backupService.restoreBackup(file);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup restored successfully. App will reload.'),
          duration: Duration(seconds: 3),
        ),
      );
      // Force app restart by popping to root and letting StoreLoader reload
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to restore backup: $e')),
      );
    } finally {
      _setBusy(_DataAction.restoreBackup, false);
    }
  }

  Future<void> _exportExcel() async {
    _setBusy(_DataAction.exportExcel, true);
    try {
      final store = StoreScope.of(context);
      final excelService = ExcelExportService(
        flats: store.flats,
        beds: store.beds,
        people: store.people,
        payments: store.payments,
        expenses: store.expenses,
        leaseChequeSettings: store.leaseChequeSettings,
        leaseChequeRecords: store.leaseChequeRecords,
        terminations: store.terminations,
      );
      final file = await excelService.exportToExcel();
      if (!mounted) return;
      await _showExcelOptions(file);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export Excel: $e')),
      );
    } finally {
      _setBusy(_DataAction.exportExcel, false);
    }
  }

  Future<void> _showExcelOptions(File file) async {
    if (!mounted) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save),
              title: const Text('Save to device'),
              onTap: () => Navigator.pop(ctx, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'save') {
      await _saveFileToDevice(file);
    } else if (choice == 'share') {
      await Share.shareXFiles([XFile(file.path)], text: 'LUCKY Excel export');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel export created and shared')),
      );
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Text field that only enables confirmation when user types "REPLACE".
class _ConfirmationTextField extends StatefulWidget {
  const _ConfirmationTextField({required this.onConfirmed});

  final ValueChanged<bool> onConfirmed;

  @override
  State<_ConfirmationTextField> createState() => _ConfirmationTextFieldState();
}

class _ConfirmationTextFieldState extends State<_ConfirmationTextField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'REPLACE',
        helperText: 'Type exactly to confirm',
      ),
      onChanged: (value) {
        widget.onConfirmed(value == 'REPLACE');
      },
    );
  }
}