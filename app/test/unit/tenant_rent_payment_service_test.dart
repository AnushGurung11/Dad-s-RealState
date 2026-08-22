import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/config.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/tenant_rent_payment_service.dart';

void main() {
  late InMemoryJsonStore store;

  Person tenant({
    String id = 'p1',
    String name = 'Alice',
    PersonStatus status = PersonStatus.active,
    double? monthlyRent = 4000,
  }) =>
      Person(
        id: id,
        name: name,
        contact: '9000000001',
        bedId: 'b1',
        flatId: 'f1',
        joinDate: DateTime(2026, 1, 1),
        plannedStayMonths: 12,
        depositAmount: 5000,
        monthlyRent: monthlyRent,
        status: status,
      );

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertBed(const Bed(
      id: 'b1',
      flatId: 'f1',
      label: 'Bed 1',
      defaultMonthlyRent: 4000,
      tenantId: 'p1',
    ));
  });

  group('recordRent (single month)', () {
    test('creates a rent payment tied to person, bed and flat', () {
      final payment = TenantRentPaymentService(store).recordRent(
        person: tenant(),
        amountPaid: 4000,
        paidDate: DateTime(2026, 7, 15),
      );

      expect(payment.type, PaymentType.rent);
      expect(payment.personId, 'p1');
      expect(payment.bedId, 'b1');
      expect(payment.flatId, 'f1');
      expect(payment.month, monthKey(DateTime(2026, 7, 15)));
      expect(payment.amountPaid, 4000);
      expect(payment.amountDue, 4000); // defaults to the person's monthlyRent
      expect(store.payments.single.id, payment.id);
    });

    test('back-dated payments land in their own month bucket', () {
      TenantRentPaymentService(store).recordRent(
        person: tenant(),
        amountPaid: 2000,
        paidDate: DateTime(2026, 5, 3),
      );
      expect(store.payments.single.month, '2026-05');
    });

    test('payablePeople excludes archived/absconded tenants', () {
      store.upsertPerson(tenant());
      store.upsertPerson(tenant(id: 'p2', name: 'Bob'));
      store.upsertPerson(tenant(id: 'p3', name: 'Carol',
          status: PersonStatus.archived));

      final names = TenantRentPaymentService(store)
          .payablePeople()
          .map((p) => p.name)
          .toList();
      expect(names, ['Alice', 'Bob']); // sorted by name; Carol excluded
    });

    test('archived tenants cannot be paid directly (stray references)', () {
      expect(
        () => TenantRentPaymentService(store).recordRent(
            person: tenant(status: PersonStatus.archived),
            amountPaid: 1000),
        throwsA(isA<PaymentException>()),
      );
    });

    test('rejects non-positive amounts', () {
      expect(
        () => TenantRentPaymentService(store)
            .recordRent(person: tenant(), amountPaid: 0),
        throwsA(isA<PaymentException>()),
      );
    });
  });

  group('recordMultiMonthPayment', () {
    test('3 months upfront creates exactly 3 Payment records in one write',
        () {
      final records = TenantRentPaymentService(store).recordMultiMonthPayment(
        person: tenant(),
        monthsPaying: 3,
        firstAmount: 4500,
        firstDate: DateTime(2026, 7, 15),
      );

      expect(records, hasLength(3));
      expect(store.payments.map((p) => p.id), containsAllInOrder([
        records[0].id,
        records[1].id,
        records[2].id,
      ]));
      expect(records.every((p) => p.type == PaymentType.rent), isTrue);
    });

    test('month 0 keeps the entered date and amount; future months default '
        'to the 1st of their calendar month at monthlyRent', () {
      final records = TenantRentPaymentService(store).recordMultiMonthPayment(
        person: tenant(), // monthlyRent = 4000
        monthsPaying: 3,
        firstAmount: 4500,
        firstDate: DateTime(2026, 7, 15),
      );

      expect(records[0].month, '2026-07');
      expect(records[0].amountPaid, 4500);

      expect(records[1].month, '2026-08');
      expect(DateTime.parse('${records[1].month}-01').day, 1);
      expect(records[1].amountPaid, 4000); // the default rent

      expect(records[2].month, '2026-09');
      expect(records[2].amountPaid, 4000);
    });

    test('edited future month amounts are honored, not overwritten by the '
        'default', () {
      final records = TenantRentPaymentService(store).recordMultiMonthPayment(
        person: tenant(),
        monthsPaying: 3,
        firstAmount: 4000,
        firstDate: DateTime(2026, 7, 1),
        futureAmounts: {2: 3500}, // landlord discounted September
      );

      expect(records[1].amountPaid, 4000); // untouched → default
      expect(records[2].amountPaid, 3500); // edited value respected
      expect(records[2].amountDue, 3500);
    });

    test('rejects a non-positive amount on any covered month', () {
      expect(
        () => TenantRentPaymentService(store).recordMultiMonthPayment(
          person: tenant(monthlyRent: 0),
          monthsPaying: 2,
          firstAmount: 1000,
          firstDate: DateTime(2026, 7, 1),
        ),
        throwsA(isA<PaymentException>()),
      );
    });
  });

  group('hasPaidForMonth (badge source)', () {
    test('true when any rent record for the month is partially/fully paid',
        () {
      TenantRentPaymentService(store).recordRent(
        person: tenant(),
        amountPaid: 1500,
        paidDate: DateTime(2026, 7, 4),
      );
      expect(
        TenantRentPaymentService.hasPaidForMonth(
            store.payments, 'p1', '2026-07'),
        isTrue,
      );
    });

    test('false when nothing was paid that month', () {
      expect(
        TenantRentPaymentService.hasPaidForMonth(
            store.payments, 'p1', '2026-07'),
        isFalse,
      );
    });
  });
}
