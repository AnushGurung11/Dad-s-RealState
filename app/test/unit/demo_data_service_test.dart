import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/config.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/demo_data_service.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/month_selection.dart';

void main() {
  group('DemoDataService', () {
    late InMemoryJsonStore store;

    setUp(() => store = InMemoryJsonStore());

    test('coveredMonths returns three months ending on the current month', () {
      final months = DemoDataService.coveredMonths();

      expect(months, hasLength(DemoDataService.monthsOfHistory));
      expect(months.last, monthKey(DateTime.now()));
      expect(months.first, monthKey(
          DateTime(DateTime.now().year, DateTime.now().month - 2, 1)));
      // Oldest first.
      expect(months.first.compareTo(months.last), lessThan(0));
    });

    test('seed populates flats, beds, tenants and financial history', () {
      DemoDataService(store).seed();

      expect(store.flats, isNotEmpty);
      expect(store.beds, isNotEmpty);
      expect(store.people, isNotEmpty);
      expect(store.payments, isNotEmpty);
      expect(store.expenses, isNotEmpty);
      expect(store.leaseChequeRecords, isNotEmpty);
      expect(store.leaseChequeSettings, isNotEmpty);
    });

    test('every payment month is discoverable by the month jump menu', () {
      DemoDataService(store).seed();

      final months = MonthSelection.monthsWithData(store);

      for (final month in DemoDataService.coveredMonths()) {
        expect(months, contains(month),
            reason: 'month $month should be reachable from the jump menu');
      }
    });

    test('each covered month has rent payments, so no month looks empty', () {
      DemoDataService(store).seed();

      for (final month in DemoDataService.coveredMonths()) {
        final payments = store.payments.where((p) => p.month == month).toList();
        expect(payments, isNotEmpty, reason: 'no rent recorded for $month');
      }
    });

    test('lease records land in their paid month, not their due month', () {
      DemoDataService(store).seed();

      for (final record in store.leaseChequeRecords) {
        expect(record.month, monthKey(record.paidDate));
      }
    });

    test('at least one lease cheque crosses a month boundary', () {
      DemoDataService(store).seed();

      final crossing = store.leaseChequeRecords
          .where((r) => monthKey(r.dueDate) != monthKey(r.paidDate))
          .toList();

      // This is the case the due-date bucketing got wrong, so the sample data
      // must contain it for the month picker to be exercised properly.
      expect(crossing, isNotEmpty);
      for (final record in crossing) {
        expect(record.month, monthKey(record.paidDate));
        expect(record.month, isNot(monthKey(record.dueDate)));
        expect(
          DemoDataService.coveredMonths(),
          contains(record.month),
          reason: 'a paid cheque should appear in a month the user can open',
        );
      }
    });

    test('includes a partially paid month so unpaid states are visible', () {
      DemoDataService(store).seed();

      final partial = store.payments
          .where((p) => p.amountPaid < p.amountDue)
          .toList();

      expect(partial, isNotEmpty);
      expect(partial.single.type, PaymentType.rent);
    });

    test('every lease due date is still upcoming, never overdue', () {
      DemoDataService(store).seed();
      final now = DateTime.now();

      for (final setting in store.leaseChequeSettings) {
        expect(
          setting.nextDueDate.isAfter(now),
          isTrue,
          reason:
              'flat ${setting.flatId} is due ${setting.nextDueDate}, which is in the past',
        );
      }
    });

    test('each paid lease cheque belongs to a month the user can open', () {
      DemoDataService(store).seed();
      final covered = DemoDataService.coveredMonths();

      for (final record in store.leaseChequeRecords) {
        expect(covered, contains(record.month));
      }
    });

    test('archived tenants are present so the archive screens have content', () {
      DemoDataService(store).seed();

      expect(store.people.any((p) => p.status == PersonStatus.archived), isTrue);
    });

    test('bed/tenant wiring is consistent', () {
      DemoDataService(store).seed();

      for (final bed in store.beds) {
        if (bed.tenantId == null) continue;
        final tenant = store.people.firstWhere((p) => p.id == bed.tenantId);
        expect(tenant.bedId, bed.id);
        expect(tenant.flatId, bed.flatId);
      }

      for (final person in store.people) {
        if (person.bedId == null) continue;
        final bed = store.beds.firstWhere((b) => b.id == person.bedId);
        expect(bed.tenantId, person.id);
      }
    });

    test('occupied bed count matches assigned tenants', () {
      DemoDataService(store).seed();

      final occupied = store.beds.where((b) => b.tenantId != null).length;
      final assigned = store.people.where((p) => p.bedId != null).length;

      expect(occupied, assigned);
      // Leaves some vacant beds on purpose.
      expect(store.beds.length, greaterThan(occupied));
    });

    test('every expense references a known flat', () {
      DemoDataService(store).seed();

      final flatIds = store.flats.map((f) => f.id).toSet();
      for (final expense in store.expenses) {
        expect(flatIds, contains(expense.flatId));
      }
    });

    test('seed is a no-op when the device already has data', () {
      store.upsertPerson(Person(
        id: 'real_person',
        name: 'Real Tenant',
        contact: '9800000000',
      ));

      expect(DemoDataService(store).hasExistingData, isTrue);
      DemoDataService(store).seed();

      expect(store.people, hasLength(1));
      expect(store.payments, isEmpty);
      expect(store.flats, isEmpty);
    });

    test('hasExistingData is false on a fresh store', () {
      expect(DemoDataService(store).hasExistingData, isFalse);
    });

    test('seeding twice on an empty store is still consistent', () {
      final service = DemoDataService(store);
      expect(service.hasExistingData, isFalse);

      service.seed();
      // Second call is blocked because the first one added data.
      service.seed();

      expect(store.people, hasLength(9));
      expect(store.flats, hasLength(3));
    });
  });
}
