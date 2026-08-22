import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/tenure_service.dart';

void main() {
  final join = DateTime(2026, 2, 10);

  Person tenant({
    int? months = 2,
    DateTime? vacatedDate,
    double? deposit = 5000,
  }) {
    return Person(
      id: 'p1',
      name: 'Alice',
      contact: '1',
      bedId: 'b1',
      joinDate: join,
      plannedStayMonths: months,
      vacatedDate: vacatedDate ?? TenureService.computedLeaveDate(join, months ?? 2),
      depositAmount: deposit,
    );
  }

  group('TenureService.computedLeaveDate', () {
    test('joinDate + plannedStayMonths', () {
      expect(
        TenureService.computedLeaveDate(DateTime(2026, 1, 15), 2),
        DateTime(2026, 3, 15),
      );
      expect(
        TenureService.computedLeaveDate(DateTime(2026, 11, 1), 3),
        DateTime(2027, 2, 1),
      );
    });
  });

  group('TenureService.totalRentOwed', () {
    test('monthlyRent × plannedStayMonths', () {
      expect(TenureService.totalRentOwed(tenant(), 4000), 8000);
    });

    test('recalculates after plannedStayMonths edit', () {
      final edited = tenant(months: 6);
      expect(TenureService.totalRentOwed(edited, 4000), 24000);
    });

    test('recalculates when vacatedDate is edited to differ from the plan', () {
      final edited = tenant(vacatedDate: DateTime(2026, 6, 20));
      // 4 full months + a partial month because day 20 > day 10.
      expect(TenureService.totalRentOwed(edited, 4000), 20000);
    });

    test('edited vacatedDate earlier than plan is respected (minimum 1 month)', () {
      final edited = tenant(vacatedDate: DateTime(2026, 2, 15));
      expect(TenureService.totalRentOwed(edited, 4000), 4000);
    });
  });

  group('TenureService.remainingBalance', () {
    test('totalRentOwed − deposit − rent payments', () {
      final payments = const [
        Payment(
          id: 'a',
          personId: 'p1',
          bedId: 'b1',
          flatId: 'f1',
          month: '2026-02',
          amountDue: 4000,
          amountPaid: 4000,
        ),
        Payment(
          id: 'b',
          personId: 'p1',
          bedId: 'b1',
          flatId: 'f1',
          month: '2026-03',
          amountDue: 4000,
          amountPaid: 1000,
        ),
      ];
      // 8000 − 5000 − (4000 + 1000) = −2000
      expect(TenureService.remainingBalance(tenant(), 4000, payments), -2000);
    });

    test('deposits do not reduce the balance twice', () {
      final payments = const [
        Payment(
          id: 'dep',
          personId: 'p1',
          bedId: 'b1',
          flatId: 'f1',
          month: '2026-02',
          amountDue: 5000,
          amountPaid: 5000,
          type: PaymentType.deposit,
        ),
      ];
      // Only the person.depositAmount field counts; the deposit payment must
      // not be double-counted: 8000 − 5000 − 0 = 3000.
      expect(TenureService.remainingBalance(tenant(), 4000, payments), 3000);
    });

    test('zero payments edge case returns the full amount owed', () {
      expect(TenureService.remainingBalance(tenant(), 4000, const []), 3000);
      expect(TenureService.remainingBalance(tenant(deposit: 0), 4000, const []), 8000);
    });
  });
}