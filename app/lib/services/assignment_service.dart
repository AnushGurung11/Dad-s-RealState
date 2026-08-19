import '../models/bed.dart';
import 'json_store.dart';

/// Raised when an assignment violates the occupancy rules.
class AssignmentException implements Exception {
  const AssignmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Pure assignment logic operating on the in-memory collections of a
/// [JsonStore]. No I/O of its own.
///
/// Rules enforced:
///  * A bed can have at most one active tenant.
///  * A person can hold at most one active bed.
///  * Unassigning never touches payment history.
class AssignmentService {
  const AssignmentService(this.store);

  final JsonStore store;

  /// Assigns [personId] to [bedId]. Throws [AssignmentException] if the bed is
  /// occupied or the person is already assigned to another bed.
  void assignTenant({required String bedId, required String personId}) {
    final bed = store.beds.firstWhere((b) => b.id == bedId);
    final person = store.people.firstWhere((p) => p.id == personId);

    if (bed.tenantId != null && bed.tenantId != personId) {
      throw AssignmentException('This bed is already occupied.');
    }
    if (person.bedId != null && person.bedId != bedId) {
      throw AssignmentException('This person already has a bed assigned.');
    }

    store.upsertBed(bed.copyWith(tenantId: personId));
    store.upsertPerson(person.copyWith(bedId: bedId));
  }

  /// Unassigns whatever tenant currently occupies [bedId]. Clears the link in
  /// both directions. Payment history is untouched.
  void unassignTenant(String bedId) {
    final bed = store.beds.firstWhere((b) => b.id == bedId);
    final tenantId = bed.tenantId;
    if (tenantId == null) return;

    store.upsertBed(bed.copyWith(clearTenantId: true));

    final tenant = store.people.where((p) => p.id == tenantId);
    if (tenant.isNotEmpty) {
      store.upsertPerson(tenant.first.copyWith(clearBedId: true));
    }
  }

  /// Returns the beds in [flatId] that currently have no tenant.
  List<Bed> vacantBedsFor(String flatId) {
    return store.beds.where((b) => b.flatId == flatId && b.tenantId == null).toList();
  }
}