import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/lease_cheque_record.dart';
import 'package:lucky/models/lease_cheque_setting.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/services/flat_deletion_service.dart';

void main() {
  final flat = Flat(
    id: 'f1',
    name: 'Alpha',
    address: '1 A Road',
    createdAt: DateTime(2026, 1, 1),
  );

  List<Payment> paymentsFor(String flatId, {int count = 1}) =>
      List.generate(
        count,
        (i) => Payment(
          id: 'pay$i',
          personId: 'p1',
          bedId: 'b1',
          flatId: flatId,
          month: '2026-01',
          amountDue: 4000,
          amountPaid: 4000,
          type: PaymentType.rent,
        ),
      );

  LeaseChequeSetting setting({
    String id = 's1',
    required String flatId,
    DateTime? nextDueDate,
    double amount = 10000,
  }) =>
      LeaseChequeSetting(
        id: id,
        flatId: flatId,
        ownerName: 'Owner',
        amount: amount,
        nextDueDate: nextDueDate ?? DateTime(2026, 3, 1),
      );

  LeaseChequeRecord record({
    String id = 'cr1',
    required String flatId,
    DateTime? dueDate,
  }) =>
      LeaseChequeRecord(
        id: id,
        flatId: flatId,
        ownerName: 'Owner',
        amount: 10000,
        dueDate: dueDate ?? DateTime(2026, 3, 1),
        paidDate: DateTime(2026, 3, 1),
        month: '2026-03',
      );

  test('brand-new flat with zero history hard-deletes', () {
    final decision = FlatDeletionService.resolveDelete(
      flat: flat,
      expenses: const [],
      leaseChequeRecords: const [],
      payments: const [],
      leaseChequeSettings: const [],
    );

    expect(decision.isHardDelete, isTrue);
    expect(decision.confirmMessage, contains('permanently deleted'));
    expect(decision.hasOutstandingDue, isFalse);
  });

  test('a single Expense forces archiving instead of deleting', () {
    final expense = Expense(
      id: 'e1',
      flatId: 'f1',
      category: ExpenseCategory.maintenance,
      amount: 200,
      date: DateTime(2026, 2, 1),
    );
    // Provide a setting with a paid current due
    final dueDate = DateTime(2026, 3, 1);
    final rec = record(flatId: 'f1', dueDate: dueDate);
    final decision = FlatDeletionService.resolveDelete(
      flat: flat,
      expenses: [expense],
      leaseChequeRecords: [rec],
      payments: const [],
      leaseChequeSettings: [setting(flatId: 'f1', nextDueDate: dueDate)],
    );

    expect(decision.isArchive, isTrue);
    expect(decision.confirmMessage, contains('archived'));
    expect(decision.hasOutstandingDue, isFalse);
  });

  test('a historical tenant Payment ties the flat to its beds forever', () {
    // The tenant left long ago; the payment record still references the flat.
    final dueDate = DateTime(2026, 3, 1);
    final rec = record(flatId: 'f1', dueDate: dueDate);
    final decision = FlatDeletionService.resolveDelete(
      flat: flat,
      expenses: const [],
      leaseChequeRecords: [rec],
      payments: paymentsFor('f1'),
      leaseChequeSettings: [setting(flatId: 'f1', nextDueDate: dueDate)],
    );

    expect(decision.isArchive, isTrue);
    expect(decision.hasOutstandingDue, isFalse);
  });

  test('a LeaseChequeRecord counts as financial history too', () {
    final rec = record(flatId: 'f1');
    expect(
      FlatDeletionService.hasFinancialHistory(
        flatId: 'f1',
        expenses: const [],
        leaseChequeRecords: [rec],
        payments: const [],
      ),
      isTrue,
    );
  });

  test('history from OTHER flats does not block deletion', () {
    expect(
      FlatDeletionService.hasFinancialHistory(
        flatId: 'f2',
        expenses: const [],
        leaseChequeRecords: const [],
        payments: paymentsFor('f1'),
      ),
      isFalse,
    );
  });

  test('flat with no history but outstanding lease due triggers hardDeleteWithOutstandingDue', () {
    final dueDate = DateTime(2026, 3, 1);
    final decision = FlatDeletionService.resolveDelete(
      flat: flat,
      expenses: const [],
      leaseChequeRecords: const [],
      payments: const [],
      leaseChequeSettings: [setting(flatId: 'f1', nextDueDate: dueDate, amount: 15000)],
    );

    expect(decision.isHardDelete, isTrue);
    expect(decision.hasOutstandingDue, isTrue);
    expect(decision.outstandingDue, 15000);
  });

  test('flat with history and outstanding lease due triggers archiveWithOutstandingDue', () {
    final dueDate = DateTime(2026, 3, 1);
    final expense = Expense(
      id: 'e1',
      flatId: 'f1',
      category: ExpenseCategory.maintenance,
      amount: 200,
      date: DateTime(2026, 2, 1),
    );
    final decision = FlatDeletionService.resolveDelete(
      flat: flat,
      expenses: [expense],
      leaseChequeRecords: const [],
      payments: const [],
      leaseChequeSettings: [setting(flatId: 'f1', nextDueDate: dueDate, amount: 15000)],
    );

    expect(decision.isArchive, isTrue);
    expect(decision.hasOutstandingDue, isTrue);
    expect(decision.outstandingDue, 15000);
  });

  test('outstanding due is null when current due is already paid', () {
    final dueDate = DateTime(2026, 3, 1);
    final rec = record(flatId: 'f1', dueDate: dueDate);
    final decision = FlatDeletionService.resolveDelete(
      flat: flat,
      expenses: const [],
      leaseChequeRecords: [rec],
      payments: const [],
      leaseChequeSettings: [setting(flatId: 'f1', nextDueDate: dueDate, amount: 15000)],
    );

    expect(decision.hasOutstandingDue, isFalse);
  });

  test('getOutstandingLeaseDue returns null when no setting exists', () {
    final due = FlatDeletionService.getOutstandingLeaseDue(
      flatId: 'f1',
      leaseChequeSettings: const [],
      leaseChequeRecords: const [],
    );
    expect(due, isNull);
  });
}
