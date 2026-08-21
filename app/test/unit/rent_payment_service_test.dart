import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/config.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/rent_payment_service.dart';

void main() {
  late InMemoryJsonStore store;

  Person tenant({
    String id = 'p1',
    String name = 'Alice',
    bool archived = false,
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
        monthlyRent: 4000,
        archived: archived,
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

  test('recordRent creates a rent payment tied to person, bed and flat', () {
    final payment = RentPaymentService(store).recordRent(
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
    RentPaymentService(store).recordRent(
      person: tenant(),
      amountPaid: 2000,
      paidDate: DateTime(2026, 5, 3),
    );
    expect(store.payments.single.month, '2026-05');
  });

  test('payablePeople excludes archived tenants even if records reference '
      'them', () {
    store.upsertPerson(tenant());
    store.upsertPerson(tenant(id: 'p2', name: 'Bob'));
    store.upsertPerson(tenant(id: 'p3', name: 'Carol', archived: true));

    final names =
        RentPaymentService(store).payablePeople().map((p) => p.name).toList();
    expect(names, ['Alice', 'Bob']); // sorted by name; Carol excluded
  });

  test('archived tenants cannot be paid directly (stray references)', () {
    expect(
      () => RentPaymentService(store)
          .recordRent(person: tenant(archived: true), amountPaid: 1000),
      throwsA(isA<PaymentException>()),
    );
  });

  test('rejects non-positive amounts', () {
    expect(
      () =>
          RentPaymentService(store).recordRent(person: tenant(), amountPaid: 0),
      throwsA(isA<PaymentException>()),
    );
  });
}
