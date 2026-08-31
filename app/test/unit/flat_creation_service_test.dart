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

    test('creating a flat does NOT create a LeaseChequeSetting (separate flow)', () {
      final flat = service.createFlat(
        name: 'Alpha',
        address: '1 A Road',
        registeredDate: DateTime(2026, 3, 1),
        contractPerson: 'Mr. Khan',
        bedCount: 5,
        defaultRentPerBed: 4000,
      );

      final settings =
          store.leaseChequeSettings.where((s) => s.flatId == flat.id).toList();
      expect(settings, isEmpty);
    });

    test('addChequeSetting creates a LeaseChequeSetting for a flat', () {
      final flat = service.createFlat(
        name: 'Alpha',
        address: '1 A Road',
        bedCount: 5,
        defaultRentPerBed: 4000,
      );

      service.addChequeSetting(
        flatId: flat.id,
        ownerName: 'Mr. Khan',
        amount: 10000,
        nextDueDate: DateTime(2026, 5, 1),
        intervalMonths: 2,
      );

      final settings =
          store.leaseChequeSettings.where((s) => s.flatId == flat.id).toList();
      expect(settings, hasLength(1));
      expect(settings.single.amount, 10000);
      expect(settings.single.ownerName, 'Mr. Khan');
      expect(settings.single.nextDueDate, DateTime(2026, 5, 1));
      expect(settings.single.intervalMonths, 2);
    });

    test('rejects bedCount outside 5-20 (reuses bed_capacity_service)', () {
      for (final bad in [4, 21]) {
        expect(
          () => service.createFlat(
            name: 'Bad',
            address: 'x',
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

    test('rejects an empty flat name and writes nothing', () {
      expect(
        () => service.createFlat(
          name: '   ',
          address: 'x',
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

    test('a created flat round-trips through disk with all beds in one batched write', () async {
      await localStore.load();
      final service = FlatCreationService(localStore);
      final flat = service.createFlat(
        name: 'Persisted',
        address: '9 P Road',
        contractPerson: 'Owner',
        bedCount: 6,
        defaultRentPerBed: 3500,
      );
      await localStore.flush();

      final reloaded = LocalJsonStore(directory: tempDir);
      await reloaded.load();

      expect(reloaded.flats.single.id, flat.id);
      expect(reloaded.beds.where((b) => b.flatId == flat.id), hasLength(6));

      final rawBeds = jsonDecode(
        File('${tempDir.path}${Platform.pathSeparator}beds.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(rawBeds['items'], hasLength(6));

      reloaded.dispose();
    });
  });
}
