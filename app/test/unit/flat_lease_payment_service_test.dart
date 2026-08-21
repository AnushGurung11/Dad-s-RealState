import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/config.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/lease_cheque_setting.dart';
import 'package:renttrack/services/flat_lease_payment_service.dart';
import 'package:renttrack/services/json_store.dart';

void main() {
  late InMemoryJsonStore store;

  final flat = Flat(
    id: 'f1',
    name: 'Alpha',
    address: '1 A Road',
    createdAt: DateTime(2026, 1, 1),
  );

  LeaseChequeSetting setting({
    String id = 's1',
    required DateTime nextDueDate,
  }) =>
      LeaseChequeSetting(
        id: id,
        flatId: 'f1',
        ownerName: 'Owner A',
        amount: 4000,
        nextDueDate: nextDueDate,
        notifyEnabled: true,
      );

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flat);
  });

  test('creates an immutable record with the entered amount and original '
      'due date', () {
    final updated = FlatLeasePaymentService(store).pay(
      setting: setting(nextDueDate: DateTime(2026, 10, 25)),
      amount: 3500,
      paidDate: DateTime(2026, 9, 20),
    );

    final record = store.leaseChequeRecords.single;
    expect(record.flatId, 'f1');
    expect(record.ownerName, 'Owner A');
    expect(record.amount, 3500); // edited amount, not the default 4000
    expect(record.dueDate, DateTime(2026, 10, 25));
    expect(record.paidDate, DateTime(2026, 9, 20));
    expect(record.month, monthKey(DateTime(2026, 10, 25)));

    expect(updated.nextDueDate, DateTime(2026, 12, 25));
  });

  test('paying EARLY advances by exactly intervalMonths from the ORIGINAL '
      'due date', () {
    // Due Oct 25, paid Sep 20 — the schedule must not drift backwards.
    FlatLeasePaymentService(store).pay(
      setting: setting(nextDueDate: DateTime(2026, 10, 25)),
      amount: 4000,
      paidDate: DateTime(2026, 9, 20),
    );
    expect(store.leaseChequeSettings.single.nextDueDate,
        DateTime(2026, 12, 25));
  });

  test('paying LATE does not drift the schedule either', () {
    // Due Oct 25, paid Nov 30 — next due is still Dec 25, not Dec 30.
    FlatLeasePaymentService(store).pay(
      setting: setting(nextDueDate: DateTime(2026, 10, 25)),
      amount: 4000,
      paidDate: DateTime(2026, 11, 30),
    );
    expect(store.leaseChequeSettings.single.nextDueDate,
        DateTime(2026, 12, 25));
  });

  test('due list keeps past-due settings and sorts ascending', () {
    final now = DateTime.now();
    store.upsertChequeSetting(
        setting(id: 's2', nextDueDate: now.add(const Duration(days: 40))));
    store.upsertChequeSetting(
        setting(id: 's3', nextDueDate: now.subtract(const Duration(days: 5))));
    store.upsertChequeSetting(
        setting(id: 's4', nextDueDate: now.add(const Duration(days: 10))));

    final ids =
        FlatLeasePaymentService(store).dueList().map((s) => s.id).toList();
    expect(ids, ['s3', 's4', 's2']);
  });

  test('rejects non-positive amounts', () {
    expect(
      () => FlatLeasePaymentService(store)
          .pay(setting: setting(nextDueDate: DateTime(2026, 10, 25)), amount: 0),
      throwsA(isA<LeasePaymentException>()),
    );
  });

  test('record and setting update land as one batched write', () {
    FlatLeasePaymentService(store).pay(
      setting: setting(nextDueDate: DateTime(2026, 10, 25)),
      amount: 4000,
    );
    expect(store.leaseChequeRecords, hasLength(1));
    expect(store.leaseChequeSettings.single.nextDueDate,
        DateTime(2026, 12, 25));
  });
}
