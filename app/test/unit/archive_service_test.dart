import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/archive_service.dart';

void main() {
  Person person({
    String id = 'p1',
    DateTime? vacated,
    List<DateTime> renewals = const [],
    bool archived = false,
    String? bedId = 'b1',
  }) =>
      Person(
        id: id,
        name: 'Alice',
        contact: '9000000001',
        bedId: bedId,
        flatId: 'f1',
        joinDate: DateTime(2026, 1, 1),
        plannedStayMonths: 12,
        vacatedDate: vacated,
        depositAmount: 5000,
        monthlyRent: 4000,
        renewalHistory: renewals,
        archived: archived,
      );

  group('shouldArchive', () {
    test('is false while vacatedDate is still in the future', () {
      final p = person(vacated: DateTime(2026, 6, 1));
      expect(ArchiveService.shouldArchive(p, DateTime(2026, 5, 31)), isFalse);
    });

    test('is false on the vacatedDate itself (it has not passed yet)', () {
      final p = person(vacated: DateTime(2026, 6, 1));
      expect(ArchiveService.shouldArchive(p, DateTime(2026, 6, 1)), isFalse);
    });

    test('is true the day after vacatedDate with no renewal', () {
      final p = person(vacated: DateTime(2026, 6, 1));
      expect(ArchiveService.shouldArchive(p, DateTime(2026, 6, 2)), isTrue);
    });

    test('is false when a renewal timestamp exists on or after vacatedDate',
        () {
      final renewedAtExpiry = person(
        vacated: DateTime(2026, 6, 1),
        renewals: [DateTime(2026, 6, 1)],
      );
      final renewedAfterExpiry = person(
        vacated: DateTime(2026, 6, 1),
        renewals: [DateTime(2026, 5, 20), DateTime(2026, 6, 3)],
      );
      expect(ArchiveService.shouldArchive(renewedAtExpiry, DateTime(2026, 7, 1)),
          isFalse);
      expect(
          ArchiveService.shouldArchive(renewedAfterExpiry, DateTime(2026, 7, 1)),
          isFalse);
    });

    test('is true when the only renewal happened before the current '
        'vacatedDate was set (stale renewal does not count)', () {
      // Renewed during an earlier cycle; the plan was later extended to a
      // new vacatedDate that has since lapsed without another renewal.
      final staleRenewal = person(
        vacated: DateTime(2026, 9, 1),
        renewals: [DateTime(2026, 5, 30)],
      );
      expect(
          ArchiveService.shouldArchive(staleRenewal, DateTime(2026, 9, 2)),
          isTrue);
    });

    test('is false for someone without a vacatedDate', () {
      expect(
        ArchiveService.shouldArchive(person(), DateTime(2030, 1, 1)),
        isFalse,
      );
    });

    test('is false for someone already archived (sweeps are idempotent)', () {
      final p = person(vacated: DateTime(2026, 6, 1), archived: true);
      expect(ArchiveService.shouldArchive(p, DateTime(2026, 7, 1)), isFalse);
    });
  });

  group('checkAndArchive', () {
    test('archives lapsed tenants, frees their beds and touches nothing else',
        () {
      final today = DateTime(2026, 7, 1);
      final lapsed = person(vacated: DateTime(2026, 6, 1));
      final active = Person(
        id: 'p2',
        name: 'Bob',
        contact: '9000000002',
        bedId: 'b2',
        flatId: 'f1',
        joinDate: DateTime(2026, 1, 1),
        plannedStayMonths: 12,
        vacatedDate: DateTime(2027, 1, 1),
      );
      const bedB1 = Bed(
          id: 'b1',
          flatId: 'f1',
          label: 'Bed 1',
          defaultMonthlyRent: 4000,
          tenantId: 'p1');
      const bedB2 = Bed(
          id: 'b2',
          flatId: 'f1',
          label: 'Bed 2',
          defaultMonthlyRent: 4200,
          tenantId: 'p2');

      final (people, beds) = ArchiveService.checkAndArchive(
        [lapsed, active],
        [bedB1, bedB2],
        today,
      );

      // Alice archived with the sweep date; her tenure data is preserved so
      // the Archive screen can show her former flat/bed.
      final archivedAlice = people[0];
      expect(archivedAlice.archived, isTrue);
      expect(archivedAlice.archivedAt, today);
      expect(archivedAlice.bedId, 'b1');
      expect(archivedAlice.depositAmount, 5000);
      expect(archivedAlice.vacatedDate, DateTime(2026, 6, 1));

      // Bob and his bed are untouched — literally the same instances.
      expect(identical(people[1], active), isTrue);
      expect(identical(beds[1], bedB2), isTrue);

      // Her bed was freed.
      expect(beds[0].tenantId, isNull);
    });

    test('leaves everyone alone when nobody qualifies', () {
      final today = DateTime(2026, 7, 1);
      final active = person(vacated: DateTime(2027, 1, 1));
      const bed = Bed(
          id: 'b1',
          flatId: 'f1',
          label: 'Bed 1',
          defaultMonthlyRent: 4000,
          tenantId: 'p1');

      final (people, beds) =
          ArchiveService.checkAndArchive([active], [bed], today);

      expect(identical(people.single, active), isTrue);
      expect(identical(beds.single, bed), isTrue);
    });
  });
}
