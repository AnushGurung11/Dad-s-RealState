import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/config.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/lease_cheque_record.dart';
import 'package:lucky/models/lease_cheque_setting.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/json_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('renttrack_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  LocalJsonStore newStore({Duration debounce = Duration.zero}) {
    return LocalJsonStore(directory: tempDir, debounce: debounce);
  }

  group('LocalJsonStore', () {
    test('write/read round-trip persists all seven collections', () async {
      final flat = Flat(
        id: 'f1',
        name: 'Sunrise Residency',
        address: '12 Lake Road',
        createdAt: DateTime(2026, 1, 15),
      );
      final bed = Bed(
        id: 'b1',
        flatId: 'f1',
        label: 'Bed A1',
        defaultMonthlyRent: 4500,
        tenantId: 'p1',
      );
      final person = Person(
        id: 'p1',
        name: 'Ramesh Gurung',
        contact: '9841000001',
        bedId: 'b1',
        joinDate: DateTime(2026, 1, 20),
        plannedStayMonths: 3,
        vacatedDate: DateTime(2026, 4, 20),
        depositAmount: 9000,
      );
      final payment = Payment(
        id: 'pay1',
        personId: 'p1',
        bedId: 'b1',
        flatId: 'f1',
        month: '2026-02',
        amountDue: 4500,
        amountPaid: 4500,
        type: PaymentType.deposit,
      );
      final expense = Expense(
        id: 'exp1',
        flatId: 'f1',
        category: ExpenseCategory.electricity,
        amount: 2200,
        date: DateTime(2026, 2, 5),
        note: 'February bill',
      );
      final checkSetting = LeaseChequeSetting(
        id: 'cs1',
        flatId: 'f1',
        ownerName: 'Govt Housing',
        amount: 5000,
        nextDueDate: DateTime(2026, 3, 20),
        intervalMonths: 2,
        notifyEnabled: true,
      );
      final checkRecord = LeaseChequeRecord(
        id: 'cr1',
        flatId: 'f1',
        ownerName: 'Govt Housing',
        amount: 5000,
        dueDate: DateTime(2026, 1, 20),
        paidDate: DateTime(2026, 1, 21),
        month: '2026-01',
      );

      final store = newStore();
      store.upsertFlat(flat);
      store.upsertBed(bed);
      store.upsertPerson(person);
      store.upsertPayment(payment);
      store.upsertExpense(expense);
      store.upsertChequeSetting(checkSetting);
      store.upsertChequeRecord(checkRecord);
      await store.flush();
      store.dispose();

      final reloaded = newStore();
      await reloaded.load();

      expect(reloaded.flats, hasLength(1));
      expect(reloaded.flats.single.name, 'Sunrise Residency');
      expect(reloaded.flats.single.address, '12 Lake Road');
      expect(reloaded.flats.single.createdAt, DateTime(2026, 1, 15));

      expect(reloaded.beds, hasLength(1));
      expect(reloaded.beds.single.defaultMonthlyRent, 4500);
      expect(reloaded.beds.single.tenantId, 'p1');

      expect(reloaded.people, hasLength(1));
      expect(reloaded.people.single.contact, '9841000001');
      expect(reloaded.people.single.bedId, 'b1');
      expect(reloaded.people.single.joinDate, DateTime(2026, 1, 20));
      expect(reloaded.people.single.plannedStayMonths, 3);
      expect(reloaded.people.single.vacatedDate, DateTime(2026, 4, 20));
      expect(reloaded.people.single.depositAmount, 9000);

      expect(reloaded.payments, hasLength(1));
      expect(reloaded.payments.single.status.name, 'paid');
      expect(reloaded.payments.single.month, '2026-02');
      expect(reloaded.payments.single.type, PaymentType.deposit);

      expect(reloaded.expenses, hasLength(1));
      expect(reloaded.expenses.single.category, ExpenseCategory.electricity);
      expect(reloaded.expenses.single.amount, 2200);
      expect(reloaded.expenses.single.note, 'February bill');

      expect(reloaded.leaseChequeSettings, hasLength(1));
      expect(reloaded.leaseChequeSettings.single.ownerName, 'Govt Housing');
      expect(reloaded.leaseChequeSettings.single.amount, 5000);
      expect(
        reloaded.leaseChequeSettings.single.nextDueDate,
        DateTime(2026, 3, 20),
      );
      expect(reloaded.leaseChequeSettings.single.intervalMonths, 2);
      expect(reloaded.leaseChequeSettings.single.notifyEnabled, isTrue);

      expect(reloaded.leaseChequeRecords, hasLength(1));
      expect(reloaded.leaseChequeRecords.single.ownerName, 'Govt Housing');
      expect(reloaded.leaseChequeRecords.single.amount, 5000);
      expect(
        reloaded.leaseChequeRecords.single.dueDate,
        DateTime(2026, 1, 20),
      );
      expect(reloaded.leaseChequeRecords.single.month, '2026-01');
      reloaded.dispose();
    });

    test('a partial .tmp file left mid-write does not corrupt real data',
        () async {
      final store = newStore();
      store.upsertFlat(
        Flat(
          id: 'f1',
          name: 'Keepsake',
          address: '1 Main St',
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      await store.flush();
      store.dispose();

      // Simulate a crash mid-write: a truncated tmp file is left behind.
      final tmpFile = File(
        '${tempDir.path}${Platform.pathSeparator}${AppConfig.flatsFileName}.tmp',
      );
      await tmpFile.writeAsString('{"schemaVersion":1,"items":[{"id":');

      final reloaded = newStore();
      await reloaded.load();
      expect(reloaded.flats.single.name, 'Keepsake');
      reloaded.dispose();
    });

    test('corrupt main file falls back to empty data instead of crashing',
        () async {
      final corruptFile = File(
        '${tempDir.path}${Platform.pathSeparator}${AppConfig.flatsFileName}',
      );
      await corruptFile.writeAsString('this is not json{');

      final store = newStore();
      await store.load();
      expect(store.flats, isEmpty);
      store.dispose();
    });

    test('schema migration hook fires on version mismatch and bumps version',
        () async {
      final metaFile = File(
        '${tempDir.path}${Platform.pathSeparator}${AppConfig.metaFileName}',
      );
      await metaFile.writeAsString('{"schemaVersion":0}');

      var migratedFrom = -1;
      var migratedTo = -1;

      final store = _MigratingStore(
        directory: tempDir,
        onMigrate: (from, to) {
          migratedFrom = from;
          migratedTo = to;
        },
      );
      await store.load();

      expect(migratedFrom, 0);
      expect(migratedTo, AppConfig.schemaVersion);

      // The meta file is now rewritten with the current version.
      final metaAfter = await metaFile.readAsString();
      final metaJson = jsonDecode(metaAfter) as Map<String, dynamic>;
      expect(metaJson['schemaVersion'], AppConfig.schemaVersion);
      store.dispose();
    });

    test('loading data from a newer schema version throws', () async {
      final metaFile = File(
        '${tempDir.path}${Platform.pathSeparator}${AppConfig.metaFileName}',
      );
      await metaFile.writeAsString(
        '{"schemaVersion":${AppConfig.schemaVersion + 1}}',
      );

      final store = newStore();
      expect(store.load(), throwsStateError);
      store.dispose();
    });

    test('empty store writes all files and reloads clean', () async {
      final store = newStore();
      await store.flush();

      final reloaded = newStore();
      await reloaded.load();
      expect(reloaded.flats, isEmpty);
      expect(reloaded.beds, isEmpty);
      expect(reloaded.people, isEmpty);
      expect(reloaded.payments, isEmpty);
      expect(reloaded.leaseChequeSettings, isEmpty);
      expect(reloaded.leaseChequeRecords, isEmpty);
      reloaded.dispose();
    });
  });
}

class _MigratingStore extends LocalJsonStore {
  _MigratingStore({required super.directory, required this.onMigrate});

  final void Function(int from, int to) onMigrate;

  @override
  Future<void> migrate({required int fromVersion, required int toVersion}) async {
    onMigrate(fromVersion, toVersion);
  }
}