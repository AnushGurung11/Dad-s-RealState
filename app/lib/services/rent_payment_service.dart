import '../config.dart';
import '../models/payment.dart';
import '../models/person.dart';
import 'json_store.dart';
import '../utils/ids.dart';

/// Raised when a rent payment request is invalid.
class PaymentException implements Exception {
  const PaymentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Records tenant rent payments into the shared ledger. Balances are never
/// stored — [TenureService] recalculates them on read from these records.
/// (The static [PaymentService] helpers answer "who owes what"; this class
/// creates the records they read.)
class RentPaymentService {
  const RentPaymentService(this.store);

  final JsonStore store;

  /// Tenants that can receive a rent payment: active, non-archived, currently
  /// assigned. Sorted by name for stable lists.
  List<Person> payablePeople() {
    return store.people
        .where((p) => p.isActiveTenant && !p.archived)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Creates a rent [Payment] for [person]. The payment's month comes from
  /// the (optionally back-dated) paid date. Throws [PaymentException] for
  /// non-positive amounts or inactive/archived tenants.
  Payment recordRent({
    required Person person,
    required double amountPaid,
    DateTime? paidDate,
    double? amountDue,
  }) {
    if (amountPaid <= 0) {
      throw const PaymentException('Enter an amount greater than 0.');
    }
    if (!person.isActiveTenant || person.archived) {
      throw const PaymentException('Only active tenants can be paid.');
    }
    final date = paidDate ?? DateTime.now();
    final payment = Payment(
      id: newId(),
      personId: person.id,
      bedId: person.bedId ?? '',
      flatId: person.flatId ?? '',
      month: monthKey(date),
      amountDue: amountDue ?? person.monthlyRent ?? 0,
      amountPaid: amountPaid,
      type: PaymentType.rent,
    );
    store.upsertPayment(payment);
    return payment;
  }
}
