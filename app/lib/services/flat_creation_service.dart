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

/// Creates flats with their auto-generated beds. Optionally creates a
/// LeaseChequeSetting if cheque details are provided. All writes happen as
/// one atomic batch.
class FlatCreationService {
  const FlatCreationService(this.store);

  final JsonStore store;

  /// Creates a [Flat] with [bedCount] beds labeled "Bed 1".."Bed N", each
  /// renting for [defaultRentPerBed] by default. Cheque details are optional
  /// and can be added later from the Cheque Flats page.
  Flat createFlat({
    required String name,
    required String address,
    DateTime? registeredDate,
    String? contractPerson,
    required int bedCount,
    required double defaultRentPerBed,
    String? landlineNumber,
    String? landlineRegisteredName,
    String? esewaNumber,
    String? wifiName,
    String? wifiPassword,
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
      registeredDate: registeredDate,
      contractPerson: contractPerson?.trim(),
      landlineNumber: landlineNumber?.trim().isEmpty == true ? null : landlineNumber?.trim(),
      landlineRegisteredName: landlineRegisteredName?.trim().isEmpty == true ? null : landlineRegisteredName?.trim(),
      esewaNumber: esewaNumber?.trim().isEmpty == true ? null : esewaNumber?.trim(),
      wifiName: wifiName?.trim().isEmpty == true ? null : wifiName?.trim(),
      wifiPassword: wifiPassword?.trim().isEmpty == true ? null : wifiPassword?.trim(),
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

    store.runBatched(() {
      store.upsertFlat(flat);
      for (final bed in beds) {
        store.upsertBed(bed);
      }
    });
    return flat;
  }

  /// Adds a cheque setting to an existing flat. Called from the Cheque Flats
  /// page when the user wants to set up recurring lease payments for a flat.
  void addChequeSetting({
    required String flatId,
    required String ownerName,
    required double amount,
    required DateTime nextDueDate,
    required int intervalMonths,
  }) {
    final setting = LeaseChequeSetting(
      id: newId(),
      flatId: flatId,
      ownerName: ownerName.trim().isEmpty ? flatId : ownerName.trim(),
      amount: amount,
      nextDueDate: nextDueDate,
      intervalMonths: intervalMonths,
    );
    store.upsertChequeSetting(setting);
  }
}
