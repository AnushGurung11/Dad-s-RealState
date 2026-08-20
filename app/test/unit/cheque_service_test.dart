import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/lease_cheque_setting.dart';
import 'package:renttrack/services/cheque_service.dart';

void main() {
  final today = DateTime(2026, 8, 20);

  LeaseChequeSetting setting({
    String id = 's1',
    String flatId = 'f1',
    String ownerName = 'Owner',
    double amount = 4000,
    DateTime? nextDueDate,
  }) {
    return LeaseChequeSetting(
      id: id,
      flatId: flatId,
      ownerName: ownerName,
      amount: amount,
      nextDueDate: nextDueDate ?? DateTime(2026, 8, 25),
    );
  }

  group('ChequeService.dueThisAndNextMonth', () {
    test('includes a check due later this month', () {
      final due = ChequeService.dueThisAndNextMonth(
        [setting(nextDueDate: DateTime(2026, 8, 25))],
        today,
      );
      expect(due, hasLength(1));
      expect(due.single.flatId, 'f1');
    });

    test('includes a check due next month', () {
      final due = ChequeService.dueThisAndNextMonth(
        [setting(nextDueDate: DateTime(2026, 9, 1))],
        today,
      );
      expect(due, hasLength(1));
    });

    test('excludes a check due in 3+ months', () {
      final due = ChequeService.dueThisAndNextMonth(
        [setting(nextDueDate: DateTime(2026, 10, 1))],
        today,
      );
      expect(due, isEmpty);
    });

    test('excludes a check already marked paid for its period', () {
      // nextDueDate has been advanced past the due window by markPaid.
      final paid = ChequeService.markPaid(
        setting(nextDueDate: DateTime(2026, 8, 10)),
        today,
      );
      final due = ChequeService.dueThisAndNextMonth([paid.setting], today);
      expect(due, isEmpty);
    });

    test('sorts results by due date', () {
      final due = ChequeService.dueThisAndNextMonth(
        [
          setting(id: 'late', nextDueDate: DateTime(2026, 9, 20)),
          setting(id: 'early', nextDueDate: DateTime(2026, 8, 5)),
          setting(id: 'mid', nextDueDate: DateTime(2026, 8, 30)),
        ],
        today,
      );
      expect(due.map((s) => s.id).toList(), ['early', 'mid', 'late']);
    });
  });

  group('ChequeService.markPaid', () {
    test('creates a CheckRecord with correct amount/ownerName/dueDate', () {
      final result = ChequeService.markPaid(
        setting(ownerName: 'Govt Housing', amount: 5500),
        today,
      );
      expect(result.record.flatId, 'f1');
      expect(result.record.ownerName, 'Govt Housing');
      expect(result.record.amount, 5500);
      expect(result.record.dueDate, DateTime(2026, 8, 25));
      expect(result.record.paidDate, today);
      expect(result.record.month, '2026-08');
    });

    test('advances nextDueDate by exactly intervalMonths', () {
      final result = ChequeService.markPaid(
        setting(nextDueDate: DateTime(2026, 8, 25)),
        today,
      );
      expect(result.setting.nextDueDate, DateTime(2026, 10, 25));
    });

    test('advances by the custom interval when set', () {
      final result = ChequeService.markPaid(
        setting(nextDueDate: DateTime(2026, 8, 25))
            .copyWith(intervalMonths: 3),
        today,
      );
      expect(result.setting.nextDueDate, DateTime(2026, 11, 25));
    });

    test('never mutates or removes prior CheckRecords', () {
      final first = ChequeService.markPaid(
        setting(nextDueDate: DateTime(2026, 6, 25)),
        today,
      );
      final second = ChequeService.markPaid(first.setting, today);
      expect(first.record.dueDate, DateTime(2026, 6, 25));
      expect(second.record.dueDate, DateTime(2026, 8, 25));
      expect(first.record, isNot(second.record));
      expect(second.setting.nextDueDate, DateTime(2026, 10, 25));
    });
  });
}