import '../models/payment.dart';
import '../models/person.dart';

/// Pure deletion rules for tenants. A person is only ever hard-deleted when
/// they have ZERO payment records — anything else (even one deposit) is real
/// financial history that must be preserved.
abstract final class TenantDeletionService {
  /// Whether [person] can be removed from the store entirely. True only if
  /// no Payment record references them.
  static bool canHardDelete(Person person, List<Payment> payments) {
    return payments.where((p) => p.personId == person.id).isEmpty;
  }
}
