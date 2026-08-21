import '../models/person.dart';
import '../services/tenure_service.dart';
import 'json_store.dart';

/// Raised when a renewal request is invalid.
class RenewalException implements Exception {
  const RenewalException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Extends an active tenant's stay. Each renewal recomputes the vacated date
/// from the plan and appends a timestamp to [Person.renewalHistory] — the
/// marker later chunks use to distinguish renewed tenants from lapsed ones.
class RenewalService {
  const RenewalService(this.store);

  final JsonStore store;

  /// Adds [additionalMonths] to the tenant's planned stay, recomputes
  /// [Person.vacatedDate] = joinDate + new plannedStayMonths, and records the
  /// renewal time. Throws [RenewalException] for inactive tenants.
  Person renew({
    required String personId,
    required int additionalMonths,
    DateTime? renewedAt,
  }) {
    if (additionalMonths < 1) {
      throw const RenewalException('A renewal must add at least 1 month.');
    }
    final person =
        store.people.where((p) => p.id == personId).firstOrNull;
    if (person == null) {
      throw const RenewalException('Tenant not found.');
    }
    if (!person.isActiveTenant) {
      throw const RenewalException(
        'Only an assigned tenant with a start date can renew.',
      );
    }
    if (person.archived) {
      throw const RenewalException('Archived tenants cannot renew.');
    }

    final months = person.plannedStayMonths! + additionalMonths;
    final updated = person.copyWith(
      plannedStayMonths: months,
      vacatedDate:
          TenureService.computedLeaveDate(person.joinDate!, months),
      renewalHistory: [
        ...person.renewalHistory,
        renewedAt ?? DateTime.now(),
      ],
    );
    store.upsertPerson(updated);
    return updated;
  }
}
