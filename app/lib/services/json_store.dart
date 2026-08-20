import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config.dart';
import '../models/bed.dart';
import '../models/expense.dart';
import '../models/flat.dart';
import '../models/lease_cheque_record.dart';
import '../models/lease_cheque_setting.dart';
import '../models/payment.dart';
import '../models/person.dart';

/// Storage interface. All reads/writes in the app go through this class so no
/// screen ever touches files directly.
abstract class JsonStore {
  List<Flat> get flats;
  List<Bed> get beds;
  List<Person> get people;
  List<Payment> get payments;
  List<Expense> get expenses;
  List<LeaseChequeSetting> get leaseChequeSettings;
  List<LeaseChequeRecord> get leaseChequeRecords;

  /// Invoked whenever a background disk write fails, so the app can surface a
  /// plain error to the user instead of crashing silently. Ignored by
  /// in-memory implementations.
  void Function(Object error, StackTrace stackTrace)? onWriteError;

  /// Loads all collections from persistent storage. Safe to call once at boot.
  Future<void> load();

  /// Persists a flat. Schedules a debounced disk write.
  void upsertFlat(Flat flat);

  /// Removes a flat and any beds belonging to it. Schedules a debounced write.
  void deleteFlat(String flatId);

  /// Persists a bed. Schedules a debounced disk write.
  void upsertBed(Bed bed);

  /// Removes a bed. Schedules a debounced write.
  void deleteBed(String bedId);

  /// Persists a person. Schedules a debounced disk write.
  void upsertPerson(Person person);

  /// Removes a person. Schedules a debounced write.
  void deletePerson(String personId);

  /// Persists a payment. Schedules a debounced write.
  void upsertPayment(Payment payment);

  /// Removes a payment. Schedules a debounced write.
  void deletePayment(String paymentId);

  /// Persists an expense. Schedules a debounced write.
  void upsertExpense(Expense expense);

  /// Removes an expense. Schedules a debounced write.
  void deleteExpense(String expenseId);

  /// Persists a flat's lease cheque setting. Schedules a debounced write.
  void upsertChequeSetting(LeaseChequeSetting setting);

  /// Appends a lease cheque payment record (immutable history). Schedules a
  /// debounced write.
  void upsertChequeRecord(LeaseChequeRecord record);

  /// Forces any pending writes to disk immediately.
  Future<void> flush();

  /// Cancels pending writes and releases resources.
  void dispose();
}

/// In-memory [JsonStore] with no I/O. Used as a fake in widget tests and as the
/// base for [LocalJsonStore].
class InMemoryJsonStore implements JsonStore {
  final List<Flat> _flats = [];
  final List<Bed> _beds = [];
  final List<Person> _people = [];
  final List<Payment> _payments = [];
  final List<Expense> _expenses = [];
  final List<LeaseChequeSetting> _chequeSettings = [];
  final List<LeaseChequeRecord> _chequeRecords = [];

  @override
  void Function(Object error, StackTrace stackTrace)? onWriteError;

  @override
  List<Flat> get flats => List.unmodifiable(_flats);

  @override
  List<Bed> get beds => List.unmodifiable(_beds);

  @override
  List<Person> get people => List.unmodifiable(_people);

  @override
  List<Payment> get payments => List.unmodifiable(_payments);

  @override
  List<Expense> get expenses => List.unmodifiable(_expenses);

  @override
  List<LeaseChequeSetting> get leaseChequeSettings =>
      List.unmodifiable(_chequeSettings);

  @override
  List<LeaseChequeRecord> get leaseChequeRecords =>
      List.unmodifiable(_chequeRecords);

  @override
  Future<void> load() async {}

  @override
  void upsertFlat(Flat flat) {
    final index = _flats.indexWhere((f) => f.id == flat.id);
    if (index >= 0) {
      _flats[index] = flat;
    } else {
      _flats.add(flat);
    }
  }

  @override
  void deleteFlat(String flatId) {
    _flats.removeWhere((f) => f.id == flatId);
    _beds.removeWhere((b) => b.flatId == flatId);
    _chequeSettings.removeWhere((s) => s.flatId == flatId);
    _chequeRecords.removeWhere((r) => r.flatId == flatId);
  }

  @override
  void upsertBed(Bed bed) {
    final index = _beds.indexWhere((b) => b.id == bed.id);
    if (index >= 0) {
      _beds[index] = bed;
    } else {
      _beds.add(bed);
    }
  }

  @override
  void deleteBed(String bedId) {
    _beds.removeWhere((b) => b.id == bedId);
    _people.removeWhere((p) => p.bedId == bedId);
  }

  @override
  void upsertPerson(Person person) {
    final index = _people.indexWhere((p) => p.id == person.id);
    if (index >= 0) {
      _people[index] = person;
    } else {
      _people.add(person);
    }
  }

  @override
  void deletePerson(String personId) {
    _people.removeWhere((p) => p.id == personId);
  }

  @override
  void upsertPayment(Payment payment) {
    final index = _payments.indexWhere((p) => p.id == payment.id);
    if (index >= 0) {
      _payments[index] = payment;
    } else {
      _payments.add(payment);
    }
  }

  @override
  void deletePayment(String paymentId) {
    _payments.removeWhere((p) => p.id == paymentId);
  }

  @override
  void upsertExpense(Expense expense) {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index >= 0) {
      _expenses[index] = expense;
    } else {
      _expenses.add(expense);
    }
  }

  @override
  void deleteExpense(String expenseId) {
    _expenses.removeWhere((e) => e.id == expenseId);
  }

  @override
  void upsertChequeSetting(LeaseChequeSetting setting) {
    final index = _chequeSettings.indexWhere((s) => s.id == setting.id);
    if (index >= 0) {
      _chequeSettings[index] = setting;
    } else {
      _chequeSettings.add(setting);
    }
  }

  @override
  void upsertChequeRecord(LeaseChequeRecord record) {
    final index = _chequeRecords.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      _chequeRecords[index] = record;
    } else {
      _chequeRecords.add(record);
    }
  }

  @override
  Future<void> flush() async {}

  @override
  void dispose() {}
}

/// File-backed [JsonStore] that persists collections as JSON files in the app
/// documents directory using atomic tmp-file + rename writes and a debounced
/// save timer.
class LocalJsonStore extends InMemoryJsonStore {
  LocalJsonStore({
    required this.directory,
    this.debounce = const Duration(milliseconds: 300),
  });

  /// Directory where the JSON files live. Injectable for tests.
  final Directory directory;
  final Duration debounce;

  Timer? _saveTimer;
  bool _disposed = false;

  Future<File> _file(String name) async {
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$name');
  }

  Future<void> _atomicWrite(File file, String contents) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(contents, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  Map<String, dynamic> _encode<T>(
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) {
    return {
      'schemaVersion': AppConfig.schemaVersion,
      'items': items.map(toJson).toList(),
    };
  }

  Future<void> _writeFile(String name, Map<String, dynamic> encoded) async {
    final file = await _file(name);
    await _atomicWrite(file, const JsonEncoder.withIndent('  ').convert(encoded));
  }

  Future<Map<String, dynamic>?> _readFile(String name) async {
    final file = await _file(name);
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on FormatException {
      // Corrupt file: fall back to empty data rather than crashing the app.
      return null;
    }
  }

  void _scheduleSave() {
    if (_disposed) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(debounce, () {
      _saveTimer = null;
      unawaited(_writeAll());
    });
  }

  Future<void> _writeAll() async {
    try {
      await Future.wait([
        _writeFile(AppConfig.metaFileName, {
          'schemaVersion': AppConfig.schemaVersion,
        }),
        _writeFile(AppConfig.flatsFileName, _encode(flats, (f) => f.toJson())),
        _writeFile(AppConfig.bedsFileName, _encode(beds, (b) => b.toJson())),
        _writeFile(AppConfig.peopleFileName, _encode(people, (p) => p.toJson())),
        _writeFile(AppConfig.paymentsFileName, _encode(payments, (p) => p.toJson())),
        _writeFile(
          AppConfig.expensesFileName,
          _encode(expenses, (e) => e.toJson()),
        ),
        _writeFile(
          AppConfig.leaseChequeSettingsFileName,
          _encode(leaseChequeSettings, (s) => s.toJson()),
        ),
        _writeFile(
          AppConfig.leaseChequeRecordsFileName,
          _encode(leaseChequeRecords, (r) => r.toJson()),
        ),
      ]);
    } catch (error, stackTrace) {
      onWriteError?.call(error, stackTrace);
    }
  }

  @override
  Future<void> load() async {
    final meta = await _readFile(AppConfig.metaFileName);
    final storedVersion = (meta?['schemaVersion'] as num?)?.toInt() ?? 0;

    if (storedVersion > AppConfig.schemaVersion) {
      throw StateError(
        'Data was written by a newer version of the app '
        '(schema $storedVersion > ${AppConfig.schemaVersion}). Please upgrade renttrack.',
      );
    }

    if (storedVersion < AppConfig.schemaVersion) {
      await migrate(fromVersion: storedVersion, toVersion: AppConfig.schemaVersion);
    }

    final rawFlats = await _readFile(AppConfig.flatsFileName);
    final rawBeds = await _readFile(AppConfig.bedsFileName);
    final rawPeople = await _readFile(AppConfig.peopleFileName);
    final rawPayments = await _readFile(AppConfig.paymentsFileName);
    final rawExpenses = await _readFile(AppConfig.expensesFileName);
    final rawChequeSettings = await _readFile(AppConfig.leaseChequeSettingsFileName);
    final rawChequeRecords = await _readFile(AppConfig.leaseChequeRecordsFileName);

    for (final item in rawFlats?['items'] as List? ?? const <Object?>[]) {
      super.upsertFlat(Flat.fromJson(item as Map<String, dynamic>));
    }
    for (final item in rawBeds?['items'] as List? ?? const <Object?>[]) {
      super.upsertBed(Bed.fromJson(item as Map<String, dynamic>));
    }
    for (final item in rawPeople?['items'] as List? ?? const <Object?>[]) {
      super.upsertPerson(Person.fromJson(item as Map<String, dynamic>));
    }
    for (final item in rawPayments?['items'] as List? ?? const <Object?>[]) {
      super.upsertPayment(Payment.fromJson(item as Map<String, dynamic>));
    }
    for (final item in rawExpenses?['items'] as List? ?? const <Object?>[]) {
      super.upsertExpense(Expense.fromJson(item as Map<String, dynamic>));
    }
    for (final item in rawChequeSettings?['items'] as List? ??
        const <Object?>[]) {
      super.upsertChequeSetting(
        LeaseChequeSetting.fromJson(item as Map<String, dynamic>),
      );
    }
    for (final item in rawChequeRecords?['items'] as List? ??
        const <Object?>[]) {
      super.upsertChequeRecord(
        LeaseChequeRecord.fromJson(item as Map<String, dynamic>),
      );
    }

    await _writeAll();
  }

  /// Migration hook, invoked by [load] when the stored schema version is older
  /// than the current one. Subclasses may override to transform data. The
  /// default implementation performs no migration.
  Future<void> migrate({required int fromVersion, required int toVersion}) async {}

  @override
  void upsertFlat(Flat flat) {
    super.upsertFlat(flat);
    _scheduleSave();
  }

  @override
  void deleteFlat(String flatId) {
    super.deleteFlat(flatId);
    _scheduleSave();
  }

  @override
  void upsertBed(Bed bed) {
    super.upsertBed(bed);
    _scheduleSave();
  }

  @override
  void deleteBed(String bedId) {
    super.deleteBed(bedId);
    _scheduleSave();
  }

  @override
  void upsertPerson(Person person) {
    super.upsertPerson(person);
    _scheduleSave();
  }

  @override
  void deletePerson(String personId) {
    super.deletePerson(personId);
    _scheduleSave();
  }

  @override
  void upsertPayment(Payment payment) {
    super.upsertPayment(payment);
    _scheduleSave();
  }

  @override
  void deletePayment(String paymentId) {
    super.deletePayment(paymentId);
    _scheduleSave();
  }

  @override
  void upsertExpense(Expense expense) {
    super.upsertExpense(expense);
    _scheduleSave();
  }

  @override
  void deleteExpense(String expenseId) {
    super.deleteExpense(expenseId);
    _scheduleSave();
  }

  @override
  void upsertChequeSetting(LeaseChequeSetting setting) {
    super.upsertChequeSetting(setting);
    _scheduleSave();
  }

  @override
  void upsertChequeRecord(LeaseChequeRecord record) {
    super.upsertChequeRecord(record);
    _scheduleSave();
  }

  @override
  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (_disposed) return;
    await _writeAll();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    _saveTimer = null;
  }
}