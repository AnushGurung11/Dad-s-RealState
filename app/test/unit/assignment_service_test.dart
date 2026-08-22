import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/assignment_service.dart';
import 'package:lucky/services/json_store.dart';

void main() {
  late InMemoryJsonStore store;
  late AssignmentService service;

  final flat = Flat(
    id: 'f1',
    name: 'Alpha',
    address: '1 A Road',
    createdAt: DateTime(2026, 1, 1),
  );

  final bed1 = const Bed(id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000);
  final bed2 = const Bed(id: 'b2', flatId: 'f1', label: 'Bed 2', defaultMonthlyRent: 4000);
  final alice = Person(id: 'p1', name: 'Alice', contact: '9000000001');
  final bob = Person(id: 'p2', name: 'Bob', contact: '9000000002');
  final joinDate = DateTime(2026, 2, 1);

  void assign(String bedId, String personId, {double deposit = 5000, int months = 2}) {
    final bed = store.beds.singleWhere((b) => b.id == bedId);
    final person = store.people.singleWhere((p) => p.id == personId);
    service.assignTenant(
      bed: bed,
      person: person,
      deposit: deposit,
      joinDate: joinDate,
      plannedStayMonths: months,
    );
  }

  setUp(() {
    store = InMemoryJsonStore();
    service = AssignmentService(store);

    store.upsertFlat(flat);
    store.upsertBed(bed1);
    store.upsertBed(bed2);
    store.upsertPerson(alice);
    store.upsertPerson(bob);
  });

  group('AssignmentService', () {
    test('assign to a vacant bed succeeds and sets tenure fields', () {
      assign('b1', 'p1');

      final storedBed = store.beds.singleWhere((b) => b.id == 'b1');
      final storedPerson = store.people.singleWhere((p) => p.id == 'p1');
      expect(storedBed.tenantId, 'p1');
      expect(storedPerson.bedId, 'b1');
      expect(storedPerson.joinDate, joinDate);
      expect(storedPerson.plannedStayMonths, 2);
      expect(storedPerson.vacatedDate, DateTime(2026, 4, 1));
      expect(storedPerson.depositAmount, 5000);
    });

    test('assignment records the deposit as income in the join month', () {
      assign('b1', 'p1', deposit: 6000);

      final depositPayment = store.payments.single;
      expect(depositPayment.type, PaymentType.deposit);
      expect(depositPayment.month, '2026-02');
      expect(depositPayment.amountDue, 6000);
      expect(depositPayment.amountPaid, 6000);
      expect(depositPayment.personId, 'p1');
      expect(depositPayment.bedId, 'b1');
      expect(depositPayment.flatId, 'f1');
    });

    test('assign with zero deposit throws', () {
      expect(
        () => assign('b1', 'p1', deposit: 0),
        throwsA(isA<AssignmentException>()),
      );
      expect(store.beds.singleWhere((b) => b.id == 'b1').tenantId, isNull);
    });

    test('assign to an occupied bed throws and leaves data unchanged', () {
      assign('b1', 'p1');

      expect(
        () => assign('b1', 'p2'),
        throwsA(isA<AssignmentException>()),
      );
      expect(store.beds.singleWhere((b) => b.id == 'b1').tenantId, 'p1');
      expect(store.people.singleWhere((p) => p.id == 'p2').bedId, isNull);
    });

    test('assigning a person already assigned elsewhere throws', () {
      assign('b1', 'p1');

      expect(
        () => assign('b2', 'p1'),
        throwsA(isA<AssignmentException>()),
      );
      expect(store.beds.singleWhere((b) => b.id == 'b2').tenantId, isNull);
    });

    test('assigning a person to their own bed again is idempotent', () {
      assign('b1', 'p1');

      expect(() => assign('b1', 'p1'), returnsNormally);
      expect(store.people.singleWhere((p) => p.id == 'p1').bedId, 'b1');
    });

    test('unassign clears bed.tenantId and person.bedId', () {
      assign('b1', 'p1');

      service.unassignTenant('b1');

      expect(store.beds.singleWhere((b) => b.id == 'b1').tenantId, isNull);
      expect(store.people.singleWhere((p) => p.id == 'p1').bedId, isNull);
    });

    test('assign denormalizes flatId onto the person; unassign clears it', () {
      assign('b1', 'p1');

      final stored = store.people.singleWhere((p) => p.id == 'p1');
      expect(stored.flatId, 'f1');

      service.unassignTenant('b1');
      expect(
        store.people.singleWhere((p) => p.id == 'p1').flatId,
        isNull,
      );
    });

    test('unassign leaves payment and deposit history untouched', () {
      store.upsertPayment(const Payment(
        id: 'pay1',
        personId: 'p1',
        bedId: 'b1',
        flatId: 'f1',
        month: '2026-01',
        amountDue: 4000,
        amountPaid: 1000,
      ));
      assign('b1', 'p1');

      service.unassignTenant('b1');

      expect(store.payments, hasLength(2));
      expect(
        store.payments.where((p) => p.type == PaymentType.deposit),
        hasLength(1),
      );
      expect(store.payments.singleWhere((p) => p.id == 'pay1').amountPaid, 1000);
    });

    test('unassigning an already-vacant bed is a no-op', () {
      expect(() => service.unassignTenant('b1'), returnsNormally);
      expect(store.beds.singleWhere((b) => b.id == 'b1').tenantId, isNull);
    });

    test('assignTenant with monthlyRent omitted defaults to the bed default',
        () {
      final person = Person(id: 'p3', name: 'Carol', contact: '9000000003');
      store.upsertPerson(person);
      service.assignTenant(
        bed: bed1,
        person: person,
        deposit: 5000,
        joinDate: joinDate,
        plannedStayMonths: 2,
      );

      final stored = store.people.singleWhere((p) => p.id == 'p3');
      expect(stored.monthlyRent, bed1.defaultMonthlyRent);
      expect(stored.monthlyRent, 4000);
    });

    test('assignTenant with monthlyRent provided overrides the bed default',
        () {
      final person = Person(id: 'p3', name: 'Carol', contact: '9000000003');
      store.upsertPerson(person);
      service.assignTenant(
        bed: bed1,
        person: person,
        deposit: 5000,
        joinDate: joinDate,
        plannedStayMonths: 2,
        monthlyRent: 3500,
      );

      final stored = store.people.singleWhere((p) => p.id == 'p3');
      expect(stored.monthlyRent, 3500);
    });

    test('a single assignTenant call atomically writes person, bed and deposit',
        () {
      final person = Person(id: 'p3', name: 'Carol', contact: '9000000003');
      store.upsertPerson(person);
      service.assignTenant(
        bed: bed1,
        person: person,
        deposit: 5000,
        joinDate: joinDate,
        plannedStayMonths: 2,
      );

      // One call produced a consistent final state: bed occupied, person
      // assigned with tenure fields, and the deposit recorded as income.
      final storedBed = store.beds.singleWhere((b) => b.id == 'b1');
      final storedPerson = store.people.singleWhere((p) => p.id == 'p3');
      expect(storedBed.tenantId, 'p3');
      expect(storedPerson.bedId, 'b1');
      expect(storedPerson.joinDate, joinDate);
      expect(storedPerson.vacatedDate, DateTime(2026, 4, 1));
      expect(storedPerson.depositAmount, 5000);
      expect(
        store.payments.singleWhere((p) => p.personId == 'p3').type,
        PaymentType.deposit,
      );
    });

    test('vacantBedsFor only lists beds without a tenant in that flat', () {
      assign('b1', 'p1');
      store.upsertBed(const Bed(id: 'b3', flatId: 'f2', label: 'Other', defaultMonthlyRent: 1));

      final vacant = service.vacantBedsFor('f1');
      expect(vacant.map((b) => b.id), ['b2']);
    });
  });
}