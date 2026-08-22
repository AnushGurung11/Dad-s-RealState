import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/lease_cheque_record.dart';
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

  test('brand-new flat with zero history hard-deletes', () {
    final decision = FlatDeletionService.resolveDelete(
      flat: flat,
      expenses: const [],
      leaseChequeRecords: const [],
      payments: const [],
    );

    expect(decision.isHardDelete, isTrue);
    expect(decision.confirmMessage,
        contains('permanently deleted'));
  });

  test('a single Expense forces archiving instead of deleting', () {
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
    );

    expect(decision.isArchive, isTrue);
    expect(decision.confirmMessage, contains('archived'));
  });

  test('a historical tenant Payment ties the flat to its beds forever',
      () {
    // The tenant left long ago; the payment record still references the flat.
    final decision = FlatDeletionService.resolveDelete(
      flat: flat,
      expenses: const [],
      leaseChequeRecords: const [],
      payments: paymentsFor('f1'),
    );

    expect(decision.isArchive, isTrue);
  });

  test('a LeaseChequeRecord counts as financial history too', () {
    final record = LeaseChequeRecord(
      id: 'cr1',
      flatId: 'f1',
      ownerName: 'Mr. Khan',
      amount: 10000,
      dueDate: DateTime(2026, 3, 1),
      paidDate: DateTime(2026, 3, 1),
      month: '2026-03',
    );
    expect(
      FlatDeletionService.hasFinancialHistory(
        flatId: 'f1',
        expenses: const [],
        leaseChequeRecords: [record],
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
}
