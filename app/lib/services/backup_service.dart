import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../config.dart';
import '../models/bed.dart';
import '../models/expense.dart';
import '../models/flat.dart';
import '../models/lease_cheque_record.dart';
import '../models/lease_termination_record.dart';
import '../models/lease_cheque_setting.dart';
import '../models/payment.dart';
import '../models/person.dart';
import 'json_store.dart';

/// Validation result for a backup file.
class RestoreValidation {
  const RestoreValidation({
    required this.valid,
    this.summary,
    this.errors,
    this.meta,
  });

  /// Whether the backup is valid and can be restored.
  final bool valid;

  /// Human-readable summary of collections in the backup (only when valid).
  final String? summary;

  /// Specific validation errors (only when invalid).
  final List<String>? errors;

  /// Parsed meta.json from the backup.
  final BackupMeta? meta;
}

/// Metadata stored in meta.json inside the backup zip.
class BackupMeta {
  const BackupMeta({
    required this.schemaVersion,
    required this.exportedAt,
    required this.appVersion,
  });

  final int schemaVersion;
  final DateTime exportedAt;
  final String appVersion;

  factory BackupMeta.fromJson(Map<String, dynamic> json) {
    return BackupMeta(
      schemaVersion: json['schemaVersion'] as int,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      appVersion: json['appVersion'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'appVersion': appVersion,
    };
  }
}

/// All data collections combined for backup/restore.
class BackupData {
  const BackupData({
    required this.flats,
    required this.beds,
    required this.people,
    required this.payments,
    required this.expenses,
    required this.leaseChequeSettings,
    required this.leaseChequeRecords,
    required this.terminations,
  });

  final List<Flat> flats;
  final List<Bed> beds;
  final List<Person> people;
  final List<Payment> payments;
  final List<Expense> expenses;
  final List<LeaseChequeSetting> leaseChequeSettings;
  final List<LeaseChequeRecord> leaseChequeRecords;
  final List<LeaseTerminationRecord> terminations;

  Map<String, dynamic> toJson() {
    return {
      'flats': flats.map((f) => f.toJson()).toList(),
      'beds': beds.map((b) => b.toJson()).toList(),
      'people': people.map((p) => p.toJson()).toList(),
      'payments': payments.map((p) => p.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'leaseChequeSettings': leaseChequeSettings.map((s) => s.toJson()).toList(),
      'leaseChequeRecords': leaseChequeRecords.map((r) => r.toJson()).toList(),
      'terminations': terminations.map((t) => t.toJson()).toList(),
    };
  }

  static BackupData fromJson(Map<String, dynamic> json) {
    return BackupData(
      flats: (json['flats'] as List).map((e) => Flat.fromJson(e as Map<String, dynamic>)).toList(),
      beds: (json['beds'] as List).map((e) => Bed.fromJson(e as Map<String, dynamic>)).toList(),
      people: (json['people'] as List).map((e) => Person.fromJson(e as Map<String, dynamic>)).toList(),
      payments: (json['payments'] as List).map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList(),
      expenses: (json['expenses'] as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList(),
      leaseChequeSettings: (json['leaseChequeSettings'] as List).map((e) => LeaseChequeSetting.fromJson(e as Map<String, dynamic>)).toList(),
      leaseChequeRecords: (json['leaseChequeRecords'] as List).map((e) => LeaseChequeRecord.fromJson(e as Map<String, dynamic>)).toList(),
      terminations: (json['terminations'] as List).map((e) => LeaseTerminationRecord.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Service for creating, validating, and restoring backups.
class BackupService {
  BackupService(this.store, {this.getDocumentsDirectory});

  final JsonStore store;

  /// Optional override for getting the documents directory (used in tests).
  final Future<Directory> Function()? getDocumentsDirectory;

  /// Creates a complete backup zip containing all data and photos.
  /// Returns the zip file; the caller should show a share sheet.
  Future<File> createBackup() async {
    final docsDir = getDocumentsDirectory != null
        ? await getDocumentsDirectory!()
        : await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final zipFile = File('${docsDir.path}/lucky-backup-$timestamp.zip');

    final encoder = ZipEncoder();

    // Build data.json
    final data = BackupData(
      flats: store.flats,
      beds: store.beds,
      people: store.people,
      payments: store.payments,
      expenses: store.expenses,
      leaseChequeSettings: store.leaseChequeSettings,
      leaseChequeRecords: store.leaseChequeRecords,
      terminations: store.terminations,
    );

    final dataJson = const JsonEncoder.withIndent('  ').convert(data.toJson());

    // Build meta.json
    final meta = BackupMeta(
      schemaVersion: AppConfig.schemaVersion,
      exportedAt: DateTime.now(),
      appVersion: '1.9.0', // TODO: read from package_info_plus
    );
    final metaJson = const JsonEncoder.withIndent('  ').convert(meta.toJson());

    // Prepare archive entries
    final archive = Archive();
    archive.addFile(ArchiveFile('data.json', dataJson.length, dataJson.codeUnits));
    archive.addFile(ArchiveFile('meta.json', metaJson.length, metaJson.codeUnits));

    // Copy photos into photos/ folder keyed by personId
    for (final person in store.people) {
      if (person.photoPath != null) {
        final photoFile = File(person.photoPath!);
        if (await photoFile.exists()) {
          final photoBytes = await photoFile.readAsBytes();
          final ext = _getExtension(person.photoPath!);
          archive.addFile(ArchiveFile('photos/${person.id}$ext', photoBytes.length, photoBytes));
        }
      }
    }

    // Write zip
    final zipBytes = encoder.encode(archive);
    if (zipBytes == null) {
      throw StateError('Failed to encode backup zip');
    }
    await zipFile.writeAsBytes(zipBytes, flush: true);

    return zipFile;
  }

  /// Validates a backup zip without modifying any data.
  /// Returns a RestoreValidation with detailed results.
  Future<RestoreValidation> validateBackup(File zipFile) async {
    if (!await zipFile.exists()) {
      return const RestoreValidation(
        valid: false,
        errors: ['Backup file does not exist'],
      );
    }

    // Extract zip to temp directory
    final tempDir = await Directory.systemTemp.createTemp('backup_validate_');
    try {
      final zipBytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // Extract to temp
      for (final file in archive) {
        final outFile = File('${tempDir.path}/${file.name}');
        await outFile.parent.create(recursive: true);
        if (file.isFile) {
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      // Parse meta.json
      final metaFile = File('${tempDir.path}/meta.json');
      if (!await metaFile.exists()) {
        return const RestoreValidation(
          valid: false,
          errors: ['Invalid backup: missing meta.json'],
        );
      }
      final metaJson = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
      final meta = BackupMeta.fromJson(metaJson);

      // Check schema version
      if (meta.schemaVersion > AppConfig.schemaVersion) {
        return RestoreValidation(
          valid: false,
          meta: meta,
          errors: [
            'This backup is from a newer app version (schema ${meta.schemaVersion} > ${AppConfig.schemaVersion}). Please update the app before restoring.',
          ],
        );
      }

      // Parse data.json
      final dataFile = File('${tempDir.path}/data.json');
      if (!await dataFile.exists()) {
        return RestoreValidation(
          valid: false,
          meta: meta,
          errors: ['Invalid backup: missing data.json'],
        );
      }
      final dataJson = jsonDecode(await dataFile.readAsString()) as Map<String, dynamic>;
      final data = BackupData.fromJson(dataJson);

      // If older schema, run migration (re-use store's migrate logic)
      // For validation, we just note it would need migration
      // ignore: unused_local_variable
      final needsMigration = meta.schemaVersion < AppConfig.schemaVersion;

      // Validate referential integrity
      final errors = _validateReferentialIntegrity(data);

      if (errors.isNotEmpty) {
        return RestoreValidation(
          valid: false,
          meta: meta,
          errors: errors,
        );
      }

      // Build summary
      final summary = 'Flats: ${data.flats.length}, '
          'Beds: ${data.beds.length}, '
          'Tenants: ${data.people.length}, '
          'Payments: ${data.payments.length}, '
          'Expenses: ${data.expenses.length}, '
          'Cheque Settings: ${data.leaseChequeSettings.length}, '
          'Cheque Records: ${data.leaseChequeRecords.length}, '
          'Terminations: ${data.terminations.length}';

      return RestoreValidation(
        valid: true,
        meta: meta,
        summary: summary,
      );
    } finally {
      // Cleanup temp dir
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Restores a validated backup. Call only after validateBackup() returns valid: true.
  /// This REPLACES all current data atomically.
  Future<void> restoreBackup(File zipFile) async {
    if (!await zipFile.exists()) {
      throw StateError('Backup file does not exist');
    }

    // Extract zip to temp directory
    final tempDir = await Directory.systemTemp.createTemp('backup_restore_');
    try {
      final zipBytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // Extract to temp
      for (final file in archive) {
        final outFile = File('${tempDir.path}/${file.name}');
        await outFile.parent.create(recursive: true);
        if (file.isFile) {
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      // Parse data.json
      final dataFile = File('${tempDir.path}/data.json');
      if (!await dataFile.exists()) {
        throw StateError('Invalid backup: missing data.json');
      }
      final dataJson = jsonDecode(await dataFile.readAsString()) as Map<String, dynamic>;
      final data = BackupData.fromJson(dataJson);

      // Parse meta.json for version info
      final metaFile = File('${tempDir.path}/meta.json');
      if (await metaFile.exists()) {
        final metaJson = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
        // ignore: unused_local_variable
        final meta = BackupMeta.fromJson(metaJson);
      }

      // Extract photos to app documents directory
      final docsDir = getDocumentsDirectory != null
          ? await getDocumentsDirectory!()
          : await getApplicationDocumentsDirectory();
      final photosDir = Directory('${docsDir.path}/photos');
      await photosDir.create(recursive: true);

      final photoPathMap = <String, String>{};
      // Find photo files in archive
      for (final file in archive) {
        if (file.name.startsWith('photos/') && file.isFile) {
          final personId = file.name.split('/').last.split('.').first;
          final ext = _getExtension(file.name);
          final newPath = '${photosDir.path}/$personId$ext';
          final newFile = File(newPath);
          await newFile.writeAsBytes(file.content as List<int>);
          photoPathMap[personId] = newPath;
        }
      }

      // Rewrite photo paths in people data
      final updatedPeople = data.people.map((person) {
        if (person.photoPath != null) {
          final personId = person.id;
          if (photoPathMap.containsKey(personId)) {
            return person.copyWith(photoPath: photoPathMap[personId]);
          }
        }
        return person;
      }).toList();

      // Atomic replace: write all collections to .tmp files then rename
      await _atomicReplaceAll(
        flats: data.flats,
        beds: data.beds,
        people: updatedPeople,
        payments: data.payments,
        expenses: data.expenses,
        leaseChequeSettings: data.leaseChequeSettings,
        leaseChequeRecords: data.leaseChequeRecords,
        terminations: data.terminations,
      );

      // Reload store from disk
      if (store is LocalJsonStore) {
        await (store as LocalJsonStore).load();
      }
    } finally {
      // Cleanup temp dir
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Validates referential integrity across all collections.
  List<String> _validateReferentialIntegrity(BackupData data) {
    final errors = <String>[];
    final flatIds = data.flats.map((f) => f.id).toSet();
    final bedIds = data.beds.map((b) => b.id).toSet();
    final personIds = data.people.map((p) => p.id).toSet();

    // Check beds reference valid flats
    for (final bed in data.beds) {
      if (!flatIds.contains(bed.flatId)) {
        errors.add('Bed ${bed.id} references non-existent flat ${bed.flatId}');
      }
    }

    // Check people reference valid beds and flats
    for (final person in data.people) {
      if (person.bedId != null && !bedIds.contains(person.bedId!)) {
        errors.add('Person ${person.id} references non-existent bed ${person.bedId}');
      }
      if (person.flatId != null && !flatIds.contains(person.flatId!)) {
        errors.add('Person ${person.id} references non-existent flat ${person.flatId}');
      }
    }

    // Check payments reference valid persons, beds, flats
    for (final payment in data.payments) {
      if (!personIds.contains(payment.personId)) {
        errors.add('Payment ${payment.id} references non-existent person ${payment.personId}');
      }
      if (!bedIds.contains(payment.bedId)) {
        errors.add('Payment ${payment.id} references non-existent bed ${payment.bedId}');
      }
      if (!flatIds.contains(payment.flatId)) {
        errors.add('Payment ${payment.id} references non-existent flat ${payment.flatId}');
      }
    }

    // Check expenses reference valid flats
    for (final expense in data.expenses) {
      if (!flatIds.contains(expense.flatId)) {
        errors.add('Expense ${expense.id} references non-existent flat ${expense.flatId}');
      }
    }

    // Check cheque settings reference valid flats
    for (final setting in data.leaseChequeSettings) {
      if (!flatIds.contains(setting.flatId)) {
        errors.add('LeaseChequeSetting ${setting.id} references non-existent flat ${setting.flatId}');
      }
    }

    // Check cheque records reference valid flats
    for (final record in data.leaseChequeRecords) {
      if (!flatIds.contains(record.flatId)) {
        errors.add('LeaseChequeRecord ${record.id} references non-existent flat ${record.flatId}');
      }
    }

    // Check terminations reference valid persons, beds, flats
    for (final term in data.terminations) {
      if (!personIds.contains(term.personId)) {
        errors.add('Termination ${term.id} references non-existent person ${term.personId}');
      }
      if (!bedIds.contains(term.bedId)) {
        errors.add('Termination ${term.id} references non-existent bed ${term.bedId}');
      }
      if (!flatIds.contains(term.flatId)) {
        errors.add('Termination ${term.id} references non-existent flat ${term.flatId}');
      }
    }

    return errors;
  }

  /// Atomically replaces all collections by writing to .tmp files then renaming.
  Future<void> _atomicReplaceAll({
    required List<Flat> flats,
    required List<Bed> beds,
    required List<Person> people,
    required List<Payment> payments,
    required List<Expense> expenses,
    required List<LeaseChequeSetting> leaseChequeSettings,
    required List<LeaseChequeRecord> leaseChequeRecords,
    required List<LeaseTerminationRecord> terminations,
  }) async {
    if (store is! LocalJsonStore) {
      throw StateError('Atomic replace only supported with LocalJsonStore');
    }

    final localStore = store as LocalJsonStore;
    final directory = localStore.directory;

    // Write all files to .tmp first
    final tmpFiles = <File>[];
    try {
      tmpFiles.add(await _writeTmpFile(directory, AppConfig.flatsFileName, flats));
      tmpFiles.add(await _writeTmpFile(directory, AppConfig.bedsFileName, beds));
      tmpFiles.add(await _writeTmpFile(directory, AppConfig.peopleFileName, people));
      tmpFiles.add(await _writeTmpFile(directory, AppConfig.paymentsFileName, payments));
      tmpFiles.add(await _writeTmpFile(directory, AppConfig.expensesFileName, expenses));
      tmpFiles.add(await _writeTmpFile(directory, AppConfig.leaseChequeSettingsFileName, leaseChequeSettings));
      tmpFiles.add(await _writeTmpFile(directory, AppConfig.leaseChequeRecordsFileName, leaseChequeRecords));
      tmpFiles.add(await _writeTmpFile(directory, AppConfig.terminationsFileName, terminations));
      tmpFiles.add(await _writeTmpMetaFile(directory, AppConfig.metaFileName));

      // Now rename all .tmp files atomically
      for (final file in tmpFiles) {
        final target = File(file.path.replaceAll('.tmp', ''));
        if (await target.exists()) {
          await target.delete();
        }
        await file.rename(target.path);
      }
    } catch (e) {
      // Cleanup any .tmp files on failure
      for (final file in tmpFiles) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<File> _writeTmpFile<T>(Directory directory, String name, List<T> items) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$name.tmp');
    final encoded = {
      'schemaVersion': AppConfig.schemaVersion,
      'items': items.map((e) => (e as dynamic).toJson() as Map<String, dynamic>).toList(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(encoded), flush: true);
    return file;
  }

  Future<File> _writeTmpMetaFile(Directory directory, String name) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$name.tmp');
    final encoded = {
      'schemaVersion': AppConfig.schemaVersion,
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(encoded), flush: true);
    return file;
  }

  String _getExtension(String path) {
    final idx = path.lastIndexOf('.');
    if (idx >= 0) {
      return path.substring(idx);
    }
    return '.jpg';
  }
}