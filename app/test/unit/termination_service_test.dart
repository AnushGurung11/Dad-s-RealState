import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/lease_termination_record.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/termination_service.dart';

void main() {
  late InMemoryJsonStore store;

  // July has 31 days.
  final alice = Person(
    id: 'p1',
    name: 'Alice',
    contact: '9000000001',
    bedId: 'b1',
    flatId: 'f1',
    joinDate: DateTime(2026, 1, 1),
    plannedStayMonths: 12,
    depositAmount: 5000,
    monthlyRent: 4000,
  );

  const bed = Bed(
      id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000,
      tenantId: 'p1');

  Payment rent(String month, double paid) => Payment(
        id: 'pay-$month',
        personId: 'p1',
        bedId: 'b1',
        flatId: 'f1',
        month: month,
        amountDue: 4000,
        amountPaid: paid,
        type: PaymentType.rent,
      );

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertBed(bed);
    store.upsertPerson(alice);
  });

  group('calculate', () {
    test('prorates the final month by days stayed', () {
      // Paid July in full; terminating on day 11 of 31.
      final calc = TerminationService.calculate(
        alice,
        [rent('2026-07', 4000)],
        DateTime(2026, 7, 11),
      );

      expect(calc.daysStayedFinalMonth, 11);
      expect(calc.paidForFinalMonth, 4000);
      expect(calc.earnedFinalMonth, closeTo(4000 * 11 / 31, 0.01));
      expect(calc.refundFutureMonths, 0);
      expect(calc.refundAmount, closeTo(4000 - 4000 * 11 / 31, 0.01));
    });

    test('includes ALL future prepaid months in the refund', () {
      // Paid July AND August AND September upfront; ending mid-July.
      final calc = TerminationService.calculate(
        alice,
        [
          rent('2026-07', 4000),
          rent('2026-08', 4200), // negotiated different rent
          rent('2026-09', 4200),
        ],
        DateTime(2026, 7, 15),
      );

      expect(calc.totalPaidAcrossPrepaidMonths, 12400);
      expect(calc.refundFutureMonths, 8400); // Aug + Sep in full
      expect(calc.refundAmount,
          closeTo((4000 - 4000 * 15 / 31) + 8400, 0.01));
    });

    test('floors the total refund at 0 when underpaid', () {
      // Only paid 500 of July's 4000; nothing prepaid ahead.
      final calc = TerminationService.calculate(
        alice,
        [rent('2026-07', 500)],
        DateTime(2026, 7, 5),
      );

      expect(calc.refundFinalMonth, lessThan(0)); // owes more than paid
      expect(calc.refundFutureMonths, 0);
      expect(calc.refundAmount, 0); // never negative — no invoicing here
    });

    test('ignores payments from OTHER people and deposits', () {
      final other = Payment(
        id: 'pay-other',
        personId: 'p2',
        bedId: 'b2',
        flatId: 'f1',
        month: '2026-09',
        amountDue: 9000,
        amountPaid: 9000,
        type: PaymentType.rent,
      );
      final deposit = Payment(
        id: 'pay-dep',
        personId: 'p1',
        bedId: 'b1',
        flatId: 'f1',
        month: '2026-09',
        amountDue: 5000,
        amountPaid: 5000,
        type: PaymentType.deposit,
      );
      final calc = TerminationService.calculate(
        alice,
        [other, deposit],
        DateTime(2026, 7, 20),
      );
      expect(calc.refundAmount, 0);
      expect(calc.totalPaidAcrossPrepaidMonths, 0);
    });
  });

  group('terminate', () {
    test('archives the tenant, sets vacatedDate, frees the bed and never '
        'touches Payment records', () {
      final payments = [rent('2026-07', 4000), rent('2026-08', 4000)];
      for (final p in payments) {
        store.upsertPayment(p);
      }
      final calc = TerminationService.calculate(
          alice, store.payments, DateTime(2026, 7, 22));

      TerminationService.terminate(
        store,
        person: alice,
        calculation: calc,
        reason: TerminationReason.financial,
        terminationDate: DateTime(2026, 7, 22),
      );

      final updated = store.people.single;
      expect(updated.status, PersonStatus.archived);
      expect(updated.vacatedDate, DateTime(2026, 7, 22));
      expect(store.beds.single.tenantId, isNull);

      expect(store.payments, hasLength(2));
      expect(identical(store.payments[0], payments[0]), isTrue);
      expect(identical(store.payments[1], payments[1]), isTrue);

      // The termination record captures the refund for future reports.
      expect(store.terminations, hasLength(1));
      expect(store.terminations.single.reason, TerminationReason.financial);
      expect(store.terminations.single.refundAmount,
          closeTo(calc.refundAmount, 0.001));
    });

    test('reason == other REQUIRES a non-empty note', () {
      final calc = TerminationService.calculate(alice, [], DateTime(2026, 7, 1));
      expect(
        () => TerminationService.terminate(
          store,
          person: alice,
          calculation: calc,
          reason: TerminationReason.other,
          reasonNote: '   ',
        ),
        throwsA(isA<TerminationException>()),
      );
      // With a real note it goes through.
      TerminationService.terminate(
        store,
        person: alice,
        calculation: calc,
        reason: TerminationReason.other,
        reasonNote: 'repeated noise complaints',
      );
      expect(store.terminations.single.reasonNote,
          'repeated noise complaints');
    });

    test('other reasons do NOT require a note', () {
      final calc = TerminationService.calculate(alice, [], DateTime(2026, 7, 1));
      TerminationService.terminate(
        store,
        person: alice,
        calculation: calc,
        reason: TerminationReason.workplaceChange,
      );
      expect(store.terminations.single.reasonNote, isNull);
    });

    test('non-active tenants cannot be terminated again', () {
      store.upsertPerson(alice.copyWith(status: PersonStatus.absconded));
      final calc = TerminationService.calculate(alice, [], DateTime(2026, 7, 1));
      expect(
        () => TerminationService.terminate(
          store,
          person: store.people.single,
          calculation: calc,
          reason: TerminationReason.financial,
        ),
        throwsA(isA<TerminationException>()),
      );
    });
  });
}
