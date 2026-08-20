import '../config.dart';
import '../models/bed.dart';
import '../models/payment.dart';
import '../models/person.dart';
import '../services/tenure_service.dart';
import 'json_store.dart';
import '../utils/ids.dart';

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
///  * Assigning requires a deposit (any positive amount).
///  * Unassigning never touches payment/deposit history.
class AssignmentService {
  const AssignmentService(this.store);

  final JsonStore store;

  /// Assigns [person] to [bed] capturing [deposit], [joinDate] and
  /// [plannedStayMonths]. Computes and sets [Person.vacatedDate]. Records the
  /// deposit as income (a deposit [Payment]) in the month of [joinDate].
  /// Throws [AssignmentException] if the bed is occupied or the person is
  /// already assigned to another bed.
  void assignTenant({
    required Bed bed,
    required Person person,
    required double deposit,
    required DateTime joinDate,
    required int plannedStayMonths,
    double? monthlyRent,
  }) {
    if (deposit <= 0) {
      throw AssignmentException('A deposit is required to assign a tenant.');
    }
    if (plannedStayMonths < 1) {
      throw AssignmentException('Planned stay must be at least 1 month.');
    }
    if (bed.tenantId != null && bed.tenantId != person.id) {
      throw AssignmentException('This bed is already occupied.');
    }
    if (person.bedId != null && person.bedId != bed.id) {
      throw AssignmentException('This person already has a bed assigned.');
    }

    final vacatedDate = TenureService.computedLeaveDate(joinDate, plannedStayMonths);

    store.upsertBed(bed.copyWith(tenantId: person.id));
    store.upsertPerson(
      person.copyWith(
        bedId: bed.id,
        joinDate: joinDate,
        plannedStayMonths: plannedStayMonths,
        vacatedDate: vacatedDate,
        depositAmount: deposit,
        monthlyRent: monthlyRent ?? person.monthlyRent,
      ),
    );
    store.upsertPayment(
      Payment(
        id: newId(),
        personId: person.id,
        bedId: bed.id,
        flatId: bed.flatId,
        month: monthKey(joinDate),
        amountDue: deposit,
        amountPaid: deposit,
        type: PaymentType.deposit,
      ),
    );
  }

  /// Unassigns whatever tenant currently occupies [bedId]. Clears the link in
  /// both directions. Payment/deposit history is untouched.
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