import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/absconded_service.dart';
import 'package:lucky/services/json_store.dart';

void main() {
  late InMemoryJsonStore store;

  const bed = Bed(
      id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000,
      tenantId: 'p1');

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

  Payment rentRecord() => const Payment(
        id: 'pay1',
        personId: 'p1',
        bedId: 'b1',
        flatId: 'f1',
        month: '2026-03',
        amountDue: 4000,
        amountPaid: 2000, // partial — history that must survive
        type: PaymentType.rent,
      );

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertBed(bed);
    store.upsertPerson(alice);
    store.upsertPayment(rentRecord());
  });

  test('marking absconded sets status/statusDate/note and frees the bed',
      () {
    final today = DateTime(2026, 7, 10);
    AbscondedService(store).markAbsconded(
      personId: 'p1',
      statusNote: 'left owing 1.5 months',
      today: today,
    );

    final updated =
        store.people.singleWhere((p) => p.id == 'p1');
    expect(updated.status, PersonStatus.absconded);
    expect(updated.statusDate, today);
    expect(updated.statusNote, 'left owing 1.5 months');
    // Bed freed.
    expect(store.beds.single.tenantId, isNull);
    // Person keeps the former flat/bed link for the archive view.
    expect(updated.bedId, 'b1');
    expect(updated.flatId, 'f1');
  });

  test('all existing Payment records remain byte-identical', () {
    final before = store.payments.single;
    AbscondedService(store).markAbsconded(
      personId: 'p1',
      statusNote: 'gone without notice',
    );
    expect(store.payments.single.id, before.id);
    expect(store.payments.single.amountPaid, before.amountPaid);
    expect(store.payments.single.month, before.month);
    expect(identical(store.payments.single, before), isTrue);
  });

  test('a note is REQUIRED — empty/whitespace notes throw', () {
    expect(
      () => AbscondedService(store)
          .markAbsconded(personId: 'p1', statusNote: '   '),
      throwsA(isA<AbscondedException>()),
    );
  });

  test('an already-archived tenant cannot be marked absconded (double '
      'processing guard)', () {
    store.upsertPerson(
      alice.copyWith(status: PersonStatus.archived),
    );
    expect(
      () => AbscondedService(store)
          .markAbsconded(personId: 'p1', statusNote: 'again'),
      throwsA(isA<AbscondedException>()),
    );
  });

  test('an already-absconded tenant cannot be processed twice either', () {
    AbscondedService(store)
        .markAbsconded(personId: 'p1', statusNote: 'first time');
    expect(
      () => AbscondedService(store)
          .markAbsconded(personId: 'p1', statusNote: 'second time'),
      throwsA(isA<AbscondedException>()),
    );
    // The FIRST note survives.
    expect(store.people.single.statusNote, 'first time');
  });
}
