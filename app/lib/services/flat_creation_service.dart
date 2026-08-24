import '../models/bed.dart';
import '../models/flat.dart';
import '../models/lease_cheque_setting.dart';
import '../services/bed_capacity_service.dart';
import '../utils/ids.dart';
import 'json_store.dart';

/// Adds [months] to [date], handling month boundaries correctly.
DateTime _addMonths(DateTime date, int months) {
  final month = date.month + months;
  final year = date.year + (month - 1) ~/ 12;
  final normalizedMonth = (month - 1) % 12 + 1;
  // Try to keep the same day, but clamp to the last day of the target month
  final day = date.day;
  final lastDayOfMonth = DateTime(year, normalizedMonth + 1, 0).day;
  final clampedDay = day > lastDayOfMonth ? lastDayOfMonth : day;
  return DateTime(year, normalizedMonth, clampedDay);
}

/// Raised when a flat creation request violates the validation rules.
class FlatCreationException implements Exception {
  const FlatCreationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Creates flats with their auto-generated beds and lease cheque setting.
/// All writes happen as one atomic batch — never N separate store writes.
class FlatCreationService {
  const FlatCreationService(this.store);

  final JsonStore store;

  /// Creates a [Flat] with [bedCount] beds labeled "Bed 1".."Bed N", each
  /// renting for [defaultRentPerBed] by default, plus the flat's recurring
  /// [LeaseChequeSetting] (amount = yearlyRent / (12 / frequencyMonths), first
  /// due on the contract date or [leasePaidThroughDate] if provided). Throws
  /// [FlatCreationException] when validation fails.
  Flat createFlat({
    required String name,
    required String address,
    DateTime? registeredDate,
    String? contractPerson,
    required double yearlyRent,
    required int bedCount,
    required double defaultRentPerBed,
    DateTime? leasePaidThroughDate,
    int frequencyMonths = 2,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FlatCreationException('Flat name is required.');
    }
    if (!BedCapacityService.canCreateFlat(bedCount)) {
      throw FlatCreationException(
        'A flat must have between ${BedCapacityService.minBeds} and '
        '${BedCapacityService.maxBeds} beds.',
      );
    }
    if (frequencyMonths < 1 || frequencyMonths > 12) {
      throw const FlatCreationException('Frequency must be between 1 and 12 months.');
    }

    final now = DateTime.now();
    final flat = Flat(
      id: newId(),
      name: trimmedName,
      address: address.trim(),
      createdAt: now,
      registeredDate: registeredDate,
      contractPerson: contractPerson?.trim(),
      yearlyRent: yearlyRent,
      leasePaidThroughDate: leasePaidThroughDate,
      frequencyMonths: frequencyMonths,
    );
    final beds = List<Bed>.generate(
      bedCount,
      (index) => Bed(
        id: newId(),
        flatId: flat.id,
        label: 'Bed ${index + 1}',
        defaultMonthlyRent: defaultRentPerBed,
      ),
    );
    final owner = flat.contractPerson;
    
    // Calculate cheque amount: yearlyRent / (12 / frequencyMonths)
    final chequesPerYear = 12 / frequencyMonths;
    final chequeAmount = yearlyRent / chequesPerYear;
    
    // Determine nextDueDate: if leasePaidThroughDate is set, use it; otherwise registeredDate + frequencyMonths
    final baseDate = registeredDate ?? now;
    final nextDueDate = leasePaidThroughDate ?? _addMonths(baseDate, frequencyMonths);
    
    final chequeSetting = LeaseChequeSetting(
      id: newId(),
      flatId: flat.id,
      ownerName: (owner == null || owner.isEmpty) ? flat.name : owner,
      amount: chequeAmount,
      nextDueDate: nextDueDate,
      intervalMonths: frequencyMonths,
    );

    store.runBatched(() {
      store.upsertFlat(flat);
      for (final bed in beds) {
        store.upsertBed(bed);
      }
      store.upsertChequeSetting(chequeSetting);
    });
    return flat;
  }
}
