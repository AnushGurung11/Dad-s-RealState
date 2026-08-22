import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/services/bed_capacity_service.dart';

void main() {
  group('BedCapacityService.canCreateFlat', () {
    test('true for 5, 10 and 20 beds', () {
      expect(BedCapacityService.canCreateFlat(5), isTrue);
      expect(BedCapacityService.canCreateFlat(10), isTrue);
      expect(BedCapacityService.canCreateFlat(20), isTrue);
    });

    test('false for 4 and 21 beds', () {
      expect(BedCapacityService.canCreateFlat(4), isFalse);
      expect(BedCapacityService.canCreateFlat(21), isFalse);
      expect(BedCapacityService.canCreateFlat(0), isFalse);
      expect(BedCapacityService.canCreateFlat(-3), isFalse);
    });
  });

  group('BedCapacityService.canAddBed', () {
    List<Bed> beds(int count) => [
          for (var i = 0; i < count; i++)
            Bed(id: 'b$i', flatId: 'f1', label: 'Bed $i', defaultMonthlyRent: 1000),
        ];

    test('true below the 20-bed maximum', () {
      expect(BedCapacityService.canAddBed(beds(5)), isTrue);
      expect(BedCapacityService.canAddBed(beds(19)), isTrue);
    });

    test('false at exactly 20 beds', () {
      expect(BedCapacityService.canAddBed(beds(20)), isFalse);
    });
  });

  group('BedCapacityService.canDeleteBed', () {
    List<Bed> beds(int count) => [
          for (var i = 0; i < count; i++)
            Bed(id: 'b$i', flatId: 'f1', label: 'Bed $i', defaultMonthlyRent: 1000),
        ];

    test('true above the 5-bed minimum', () {
      expect(BedCapacityService.canDeleteBed(beds(6)), isTrue);
      expect(BedCapacityService.canDeleteBed(beds(20)), isTrue);
    });

    test('false at exactly 5 beds', () {
      expect(BedCapacityService.canDeleteBed(beds(5)), isFalse);
      expect(BedCapacityService.canDeleteBed(beds(0)), isFalse);
    });
  });
}