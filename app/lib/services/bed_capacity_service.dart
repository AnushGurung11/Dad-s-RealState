import '../models/bed.dart';

/// Pure bed-capacity rules. A flat must always have between 5 and 20 beds.
abstract final class BedCapacityService {
  static const int minBeds = 5;
  static const int maxBeds = 20;

  /// Whether a flat can be created with the given [bedCount] (5-20 inclusive).
  static bool canCreateFlat(int bedCount) {
    return bedCount >= minBeds && bedCount <= maxBeds;
  }

  /// Whether another bed can be added to [beds]. False when the flat already
  /// has 20 beds.
  static bool canAddBed(List<Bed> beds) {
    return beds.length < maxBeds;
  }

  /// Whether a bed can be removed from [beds]. False when removal would drop
  /// the flat below 5 beds.
  static bool canDeleteBed(List<Bed> beds) {
    return beds.length > minBeds;
  }
}