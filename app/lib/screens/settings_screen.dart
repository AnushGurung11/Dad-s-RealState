import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

class _DataSectionState extends State<_DataSection> {
  bool _isBusy = false;

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
            trailing: _isBusy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isBusy ? null : _createBackup,
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            key: const Key('settings_restore_backup'),
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore from backup'),
            subtitle: const Text('Replace all data with a backup zip (destructive)'),
            trailing: _isBusy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isBusy ? null : _restoreBackup,
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            key: const Key('settings_export_excel'),
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export to Excel'),
            subtitle: const Text('One-way export for viewing (7 sheets, never re-imported)'),
            trailing: _isBusy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isBusy ? null : _exportExcel,
          ),
        ),
      ],
    );
  }

  Future<void> _createBackup() async {
    setState(() => _isBusy = true);
    try {
      final store = StoreScope.of(context);
      final backupService = BackupService(store);
      final file = await backupService.createBackup();
      if (!mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: 'LUCKY backup');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup created and shared')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create backup: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    setState(() => _isBusy = true);
    try {
      // Pick backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        dialogTitle: 'Select backup zip to restore',
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final file = File(result.files.single.path!);

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
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _isBusy = true);
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
      await Share.shareXFiles([XFile(file.path)], text: 'LUCKY Excel export');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel export created and shared')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export Excel: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
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