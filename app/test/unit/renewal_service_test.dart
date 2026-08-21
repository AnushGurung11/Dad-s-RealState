import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/assignment_service.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/renewal_service.dart';

void main() {
  late InMemoryJsonStore store;
  late RenewalService service;

  final joinDate = DateTime(2026, 2, 1);

  setUp(() {
    store = InMemoryJsonStore();
    service = RenewalService(store);
    store.upsertBed(const Bed(
        id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000));
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      contact: '9000000001',
      bedId: 'b1',
      flatId: 'f1',
      joinDate: joinDate,
      plannedStayMonths: 12,
    ));
  });

  void assign() {
    AssignmentService(store).assignTenant(
      bed: store.beds.singleWhere((b) => b.id == 'b1'),
      person: store.people.singleWhere((p) => p.id == 'p1'),
      deposit: 5000,
      joinDate: joinDate,
      plannedStayMonths: 12,
    );
  }

  group('RenewalService', () {
    test('renew() extends plannedStayMonths and recomputes vacatedDate '
        'correctly', () {
      assign();
      expect(
        store.people.single.plannedStayMonths,
        12,
        reason: 'fixture sanity',
      );

      service.renew(personId: 'p1', additionalMonths: 3);

      final person = store.people.single;
      expect(person.plannedStayMonths, 15);
      expect(person.vacatedDate, DateTime(2027, 5, 1));
    });

    test('renew() appends a timestamp to renewalHistory without clearing '
        'prior entries', () {
      assign();
      final first = DateTime(2026, 3, 1, 9);
      final second = DateTime(2026, 6, 1, 9);

      service.renew(
          personId: 'p1', additionalMonths: 1, renewedAt: first);
      service.renew(
          personId: 'p1', additionalMonths: 2, renewedAt: second);

      final history = store.people.single.renewalHistory;
      expect(history, [first, second]);
      expect(history.first, first, reason: 'prior entries are preserved');
    });

    test('renew() rejects fewer than one additional month', () {
      assign();
      expect(
        () => service.renew(personId: 'p1', additionalMonths: 0),
        throwsA(isA<RenewalException>()),
      );
      expect(store.people.single.plannedStayMonths, 12);
    });

    test('renew() rejects a tenant without an active assignment', () {
      store.upsertPerson(const Person(id: 'p2', name: 'Bob', contact: 'x'));
      expect(
        () => service.renew(personId: 'p2', additionalMonths: 3),
        throwsA(isA<RenewalException>()),
      );
    });
  });
}
