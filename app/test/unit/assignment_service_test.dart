import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/assignment_service.dart';
import 'package:renttrack/services/json_store.dart';

void main() {
  late InMemoryJsonStore store;
  late AssignmentService service;

  final flat = Flat(
    id: 'f1',
    name: 'Alpha',
    address: '1 A Road',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    store = InMemoryJsonStore();
    service = AssignmentService(store);

    store.upsertFlat(flat);
    store.upsertBed(const Bed(id: 'b1', flatId: 'f1', label: 'Bed 1', monthlyRent: 4000));
    store.upsertBed(const Bed(id: 'b2', flatId: 'f1', label: 'Bed 2', monthlyRent: 4000));
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      phone: '9000000001',
      moveInDate: DateTime(2026, 1, 1),
    ));
    store.upsertPerson(Person(
      id: 'p2',
      name: 'Bob',
      phone: '9000000002',
      moveInDate: DateTime(2026, 1, 1),
    ));
  });

  group('AssignmentService', () {
    test('assign to a vacant bed succeeds', () {
      service.assignTenant(bedId: 'b1', personId: 'p1');

      expect(store.beds.singleWhere((b) => b.id == 'b1').tenantId, 'p1');
      expect(store.people.singleWhere((p) => p.id == 'p1').bedId, 'b1');
    });

    test('assign to an occupied bed throws and leaves data unchanged', () {
      service.assignTenant(bedId: 'b1', personId: 'p1');

      expect(
        () => service.assignTenant(bedId: 'b1', personId: 'p2'),
        throwsA(isA<AssignmentException>()),
      );
      expect(store.beds.singleWhere((b) => b.id == 'b1').tenantId, 'p1');
      expect(store.people.singleWhere((p) => p.id == 'p2').bedId, isNull);
    });

    test('assigning a person already assigned elsewhere throws', () {
      service.assignTenant(bedId: 'b1', personId: 'p1');

      expect(
        () => service.assignTenant(bedId: 'b2', personId: 'p1'),
        throwsA(isA<AssignmentException>()),
      );
      expect(store.beds.singleWhere((b) => b.id == 'b2').tenantId, isNull);
    });

    test('assigning a person to their own bed again is idempotent', () {
      service.assignTenant(bedId: 'b1', personId: 'p1');

      expect(() => service.assignTenant(bedId: 'b1', personId: 'p1'), returnsNormally);
      expect(store.people.singleWhere((p) => p.id == 'p1').bedId, 'b1');
    });

    test('unassign clears bed.tenantId and person.bedId', () {
      service.assignTenant(bedId: 'b1', personId: 'p1');

      service.unassignTenant('b1');

      expect(store.beds.singleWhere((b) => b.id == 'b1').tenantId, isNull);
      expect(store.people.singleWhere((p) => p.id == 'p1').bedId, isNull);
    });

    test('unassign leaves payment history untouched', () {
      store.upsertPayment(const Payment(
        id: 'pay1',
        personId: 'p1',
        bedId: 'b1',
        flatId: 'f1',
        month: '2026-01',
        amountDue: 4000,
        amountPaid: 1000,
      ));
      service.assignTenant(bedId: 'b1', personId: 'p1');

      service.unassignTenant('b1');

      expect(store.payments, hasLength(1));
      expect(store.payments.single.personId, 'p1');
      expect(store.payments.single.amountPaid, 1000);
    });

    test('unassigning an already-vacant bed is a no-op', () {
      expect(() => service.unassignTenant('b1'), returnsNormally);
      expect(store.beds.singleWhere((b) => b.id == 'b1').tenantId, isNull);
    });

    test('vacantBedsFor only lists beds without a tenant in that flat', () {
      service.assignTenant(bedId: 'b1', personId: 'p1');
      store.upsertBed(const Bed(id: 'b3', flatId: 'f2', label: 'Other', monthlyRent: 1));

      final vacant = service.vacantBedsFor('f1');
      expect(vacant.map((b) => b.id), ['b2']);
    });
  });
}