import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/services/bed_capacity_service.dart';
import 'package:lucky/services/flat_creation_service.dart';
import 'package:lucky/services/json_store.dart';

void main() {
  late InMemoryJsonStore store;
  late FlatCreationService service;

  setUp(() {
    store = InMemoryJsonStore();
    service = FlatCreationService(store);
  });

  group('FlatCreationService', () {
    test('creating a flat with bedCount N produces exactly N beds, labeled '
        'sequentially, each with the given default rent', () {
      final flat = service.createFlat(
        name: 'Alpha',
        address: '1 A Road',
        yearlyRent: 60000,
        bedCount: 7,
        defaultRentPerBed: 4000,
      );

      final beds = store.beds.where((b) => b.flatId == flat.id).toList();
      expect(beds, hasLength(7));
      expect(beds.map((b) => b.label).toList(),
          ['Bed 1', 'Bed 2', 'Bed 3', 'Bed 4', 'Bed 5', 'Bed 6', 'Bed 7']);
      expect(beds.every((b) => b.defaultMonthlyRent == 4000), isTrue);
      expect(beds.every((b) => b.tenantId == null), isTrue);
    });

    test('creating a flat also creates exactly one LeaseChequeSetting with '
        'amount == yearlyRent / 6 (default frequencyMonths=2)', () {
      final flat = service.createFlat(
        name: 'Alpha',
        address: '1 A Road',
        registeredDate: DateTime(2026, 3, 1),
        contractPerson: 'Mr. Khan',
        yearlyRent: 60000,
        bedCount: 5,
        defaultRentPerBed: 4000,
      );

      final settings =
          store.leaseChequeSettings.where((s) => s.flatId == flat.id).toList();
      expect(settings, hasLength(1));
      expect(settings.single.amount, closeTo(10000, 0.001));
      expect(settings.single.ownerName, 'Mr. Khan');
      // With default frequencyMonths=2 and no leasePaidThroughDate, nextDueDate = registeredDate + 2 months
      expect(settings.single.nextDueDate, DateTime(2026, 5, 1));
      expect(settings.single.intervalMonths, 2);
    });

    test('creating a flat with leasePaidThroughDate uses it for nextDueDate', () {
      final flat = service.createFlat(
        name: 'Alpha',
        address: '1 A Road',
        registeredDate: DateTime(2026, 3, 1),
        yearlyRent: 60000,
        bedCount: 5,
        defaultRentPerBed: 4000,
        leasePaidThroughDate: DateTime(2024, 1, 15),
        frequencyMonths: 2,
      );

      final settings =
          store.leaseChequeSettings.where((s) => s.flatId == flat.id).toList();
      expect(settings, hasLength(1));
      expect(settings.single.nextDueDate, DateTime(2024, 1, 15));
      expect(settings.single.intervalMonths, 2);
    });

    test('creating a flat with custom frequencyMonths calculates cheque amount correctly', () {
      final flat = service.createFlat(
        name: 'Alpha',
        address: '1 A Road',
        registeredDate: DateTime(2026, 3, 1),
        yearlyRent: 60000,
        bedCount: 5,
        defaultRentPerBed: 4000,
        frequencyMonths: 3,
      );

      final settings =
          store.leaseChequeSettings.where((s) => s.flatId == flat.id).toList();
      expect(settings, hasLength(1));
      // yearlyRent / (12/3) = 60000 / 4 = 15000
      expect(settings.single.amount, closeTo(15000, 0.001));
      expect(settings.single.intervalMonths, 3);
      // nextDueDate = registeredDate + 3 months = 2026-06-01
      expect(settings.single.nextDueDate, DateTime(2026, 6, 1));
    });

    test('creating a flat with both leasePaidThroughDate and custom frequency uses leasePaidThroughDate for nextDueDate', () {
      final flat = service.createFlat(
        name: 'Alpha',
        address: '1 A Road',
        registeredDate: DateTime(2026, 3, 1),
        yearlyRent: 60000,
        bedCount: 5,
        defaultRentPerBed: 4000,
        leasePaidThroughDate: DateTime(2024, 1, 15),
        frequencyMonths: 3,
      );

      final settings =
          store.leaseChequeSettings.where((s) => s.flatId == flat.id).toList();
      expect(settings, hasLength(1));
      expect(settings.single.nextDueDate, DateTime(2024, 1, 15));
      expect(settings.single.intervalMonths, 3);
      expect(settings.single.amount, closeTo(15000, 0.001));
    });

    test('rejects bedCount outside 5-20 (reuses bed_capacity_service)', () {
      for (final bad in [4, 21]) {
        expect(
          () => service.createFlat(
            name: 'Bad',
            address: 'x',
            yearlyRent: 60000,
            bedCount: bad,
            defaultRentPerBed: 4000,
          ),
          throwsA(isA<FlatCreationException>()),
          reason: '$bad beds must be rejected',
        );
      }
      expect(BedCapacityService.canCreateFlat(5), isTrue);
      expect(BedCapacityService.canCreateFlat(20), isTrue);
      // Nothing was written on failure.
      expect(store.flats, isEmpty);
      expect(store.beds, isEmpty);
      expect(store.leaseChequeSettings, isEmpty);
    });

    test('rejects frequencyMonths outside 1-12', () {
      for (final bad in [0, 13]) {
        expect(
          () => service.createFlat(
            name: 'Bad',
            address: 'x',
            yearlyRent: 60000,
            bedCount: 5,
            defaultRentPerBed: 4000,
            frequencyMonths: bad,
          ),
          throwsA(isA<FlatCreationException>()),
          reason: '$bad frequencyMonths must be rejected',
        );
      }
      expect(store.flats, isEmpty);
      expect(store.beds, isEmpty);
      expect(store.leaseChequeSettings, isEmpty);
    });

    test('rejects an empty flat name and writes nothing', () {
      expect(
        () => service.createFlat(
          name: '   ',
          address: 'x',
          yearlyRent: 60000,
          bedCount: 5,
          defaultRentPerBed: 4000,
        ),
        throwsA(isA<FlatCreationException>()),
      );
      expect(store.flats, isEmpty);
    });
  });

  group('FlatCreationService persistence', () {
    late Directory tempDir;
    late LocalJsonStore localStore;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('renttrack_test');
      localStore = LocalJsonStore(directory: tempDir, debounce: Duration.zero);
    });

    tearDown(() {
      localStore.dispose();
      tempDir.deleteSync(recursive: true);
    });

    test('a created flat round-trips through disk with all beds and the '
        'cheque setting in one batched write', () async {
      await localStore.load();
      final service = FlatCreationService(localStore);
      final flat = service.createFlat(
        name: 'Persisted',
        address: '9 P Road',
        contractPerson: 'Owner',
        yearlyRent: 72000,
        bedCount: 6,
        defaultRentPerBed: 3500,
      );
      await localStore.flush();

      final reloaded = LocalJsonStore(directory: tempDir);
      await reloaded.load();

      expect(reloaded.flats.single.id, flat.id);
      expect(reloaded.beds.where((b) => b.flatId == flat.id), hasLength(6));
      expect(reloaded.leaseChequeSettings.single.amount, 12000);

      final rawBeds = jsonDecode(
        File('${tempDir.path}${Platform.pathSeparator}beds.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(rawBeds['items'], hasLength(6));

      reloaded.dispose();
    });
  });
}
