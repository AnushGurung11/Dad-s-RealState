import '../models/bed.dart';
import '../models/flat.dart';
import '../models/lease_cheque_setting.dart';
import '../services/bed_capacity_service.dart';
import '../utils/ids.dart';
import 'json_store.dart';

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

  /// Number of lease cheques per year — the auto-calc rule divides the yearly
  /// rent by this to get each cheque's amount.
  static const int chequesPerYear = 6;

  /// Creates a [Flat] with [bedCount] beds labeled "Bed 1".."Bed N", each
  /// renting for [defaultRentPerBed] by default, plus the flat's recurring
  /// [LeaseChequeSetting] (amount = yearlyRent / 6, first due on the contract
  /// date). Throws [FlatCreationException] when validation fails.
  Flat createFlat({
    required String name,
    required String address,
    DateTime? contractDate,
    String? contractPerson,
    required double yearlyRent,
    required int bedCount,
    required double defaultRentPerBed,
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

    final now = DateTime.now();
    final flat = Flat(
      id: newId(),
      name: trimmedName,
      address: address.trim(),
      createdAt: now,
      contractDate: contractDate,
      contractPerson: contractPerson?.trim(),
      yearlyRent: yearlyRent,
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
    final chequeSetting = LeaseChequeSetting(
      id: newId(),
      flatId: flat.id,
      ownerName: (owner == null || owner.isEmpty) ? flat.name : owner,
      amount: yearlyRent / chequesPerYear,
      nextDueDate: contractDate ?? now,
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
