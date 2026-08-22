import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/payment_service.dart';

const payment1 = Payment(
  id: 'p1',
  personId: 'personA',
  bedId: 'b1',
  flatId: 'f1',
  month: '2026-02',
  amountDue: 4000,
  amountPaid: 4000,
);
const payment2 = Payment(
  id: 'p2',
  personId: 'personB',
  bedId: 'b2',
  flatId: 'f1',
  month: '2026-02',
  amountDue: 4000,
  amountPaid: 1500,
);
const payment3 = Payment(
  id: 'p3',
  personId: 'personC',
  bedId: 'b3',
  flatId: 'f2',
  month: '2026-02',
  amountDue: 5000,
  amountPaid: 0,
);
const payment4 = Payment(
  id: 'p4',
  personId: 'personA',
  bedId: 'b1',
  flatId: 'f1',
  month: '2026-01',
  amountDue: 4000,
  amountPaid: 0,
);

const beds = [
  Bed(id: 'b1', flatId: 'f1', label: 'A1', defaultMonthlyRent: 4000),
  Bed(id: 'b2', flatId: 'f1', label: 'A2', defaultMonthlyRent: 4000),
  Bed(id: 'b3', flatId: 'f2', label: 'B1', defaultMonthlyRent: 5000),
];

final people = [
  Person(id: 'personA', name: 'Alice', contact: '1'),
  Person(id: 'personB', name: 'Bob', contact: '2'),
  Person(id: 'personC', name: 'Carol', contact: '3'),
];

void main() {
  group('PaymentService.duesForBed', () {
    test('sums outstanding amounts for a bed in a month', () {
      final due = PaymentService.duesForBed(
        payments: const [payment1, payment2, payment4],
        bedId: 'b1',
        month: '2026-02',
      );
      expect(due, 0);
    });

    test('returns zero when no payments match', () {
      final due = PaymentService.duesForBed(
        payments: const [payment1],
        bedId: 'missing',
        month: '2026-02',
      );
      expect(due, 0);
    });
  });

  group('PaymentService.duesForFlat', () {
    test('sums across all beds in a flat for a month', () {
      final due = PaymentService.duesForFlat(
        payments: const [payment1, payment2, payment3, payment4],
        beds: beds,
        flatId: 'f1',
        month: '2026-02',
      );
      // 0 + (4000 - 1500) = 2500
      expect(due, 2500);
    });
  });

  group('PaymentService.overdueTenants', () {
    test('returns only unpaid or partial people for the month', () {
      final overdue = PaymentService.overdueTenants(
        payments: const [payment1, payment2, payment3, payment4],
        people: people,
        month: '2026-02',
      );
      expect(overdue.map((p) => p.id).toSet(), {'personB', 'personC'});
    });

    test('ignores other months', () {
      final overdue = PaymentService.overdueTenants(
        payments: const [payment4],
        people: people,
        month: '2026-02',
      );
      expect(overdue, isEmpty);
    });
  });

  group('PaymentService.monthlyTotals', () {
    test('sums due, paid and outstanding across flats', () {
      final totals = PaymentService.monthlyTotals(
        payments: const [payment1, payment2, payment3],
        month: '2026-02',
      );
      expect(totals.due, 13000);
      expect(totals.paid, 5500);
      expect(totals.outstanding, 7500);
    });

    test('empty data returns zero totals', () {
      final totals = PaymentService.monthlyTotals(
        payments: const [],
        month: '2026-02',
      );
      expect(totals.due, 0);
      expect(totals.paid, 0);
      expect(totals.outstanding, 0);
    });
  });

  group('PaymentService.markPaid / markPartial / markUnpaid', () {
    test('markPaid sets paid amount to due amount and status to paid', () {
      final paid = PaymentService.markPaid(payment2);
      expect(paid.amountPaid, 4000);
      expect(paid.status, PaymentStatus.paid);
    });

    test('markPartial sets the given amount and clamps to due', () {
      final partial = PaymentService.markPartial(payment3, amount: 2000);
      expect(partial.amountPaid, 2000);
      expect(partial.status, PaymentStatus.partial);

      final overpay = PaymentService.markPartial(payment3, amount: 9000);
      expect(overpay.amountPaid, 5000);
      expect(overpay.status, PaymentStatus.paid);
    });

    test('markUnpaid zeroes the paid amount', () {
      final unpaid = PaymentService.markUnpaid(payment1);
      expect(unpaid.amountPaid, 0);
      expect(unpaid.status, PaymentStatus.unpaid);
    });

    test('status getter reflects paid/partial/unpaid', () {
      expect(payment1.status, PaymentStatus.paid);
      expect(payment2.status, PaymentStatus.partial);
      expect(payment3.status, PaymentStatus.unpaid);
    });
  });
}