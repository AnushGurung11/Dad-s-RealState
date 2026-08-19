import '../models/bed.dart';
import '../models/payment.dart';
import '../models/person.dart';

/// Pure payment logic operating on in-memory lists. No I/O, unit-testable with
/// fixture data.
abstract final class PaymentService {
  /// Sum of what is currently owed for the given bed in the given month.
  static double duesForBed({
    required List<Payment> payments,
    required String bedId,
    required String month,
  }) {
    return payments
        .where((p) => p.bedId == bedId && p.month == month)
        .fold(0, (sum, p) => sum + (p.amountDue - p.amountPaid));
  }

  /// Sum of what is currently owed for the given flat in the given month.
  static double duesForFlat({
    required List<Payment> payments,
    required List<Bed> beds,
    required String flatId,
    required String month,
  }) {
    final bedIds = beds.where((b) => b.flatId == flatId).map((b) => b.id).toSet();
    return payments
        .where((p) => bedIds.contains(p.bedId) && p.month == month)
        .fold(0, (sum, p) => sum + (p.amountDue - p.amountPaid));
  }

  /// People whose most recent payment record for [month] is unpaid or partial.
  static List<Person> overdueTenants({
    required List<Payment> payments,
    required List<Person> people,
    required String month,
  }) {
    final overduePersonIds = <String>{};
    for (final payment in payments.where((p) => p.month == month)) {
      if (payment.status != PaymentStatus.paid) {
        overduePersonIds.add(payment.personId);
      }
    }
    return people.where((p) => overduePersonIds.contains(p.id)).toList();
  }

  /// Sum of due, paid and outstanding amounts across all flats for [month].
  static ({double due, double paid, double outstanding}) monthlyTotals({
    required List<Payment> payments,
    required String month,
  }) {
    var due = 0.0;
    var paid = 0.0;
    for (final payment in payments.where((p) => p.month == month)) {
      due += payment.amountDue;
      paid += payment.amountPaid;
    }
    return (due: due, paid: paid, outstanding: due - paid);
  }

  /// Marks a payment fully paid: sets [Payment.amountPaid] to [Payment.amountDue].
  static Payment markPaid(Payment payment) {
    return payment.copyWith(amountPaid: payment.amountDue);
  }

  /// Marks a payment partially paid with the given [amount].
  static Payment markPartial(Payment payment, {required double amount}) {
    return payment.copyWith(amountPaid: amount.clamp(0, payment.amountDue));
  }

  /// Marks a payment as unpaid (amount paid = 0).
  static Payment markUnpaid(Payment payment) {
    return payment.copyWith(amountPaid: 0);
  }
}