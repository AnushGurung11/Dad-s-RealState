import '../config.dart';
import '../models/lease_termination_record.dart';
import '../models/payment.dart';
import '../models/person.dart';
import 'json_store.dart';
import '../utils/ids.dart';

/// Raised when a termination request is invalid.
class TerminationException implements Exception {
  const TerminationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The proration math for ending a tenure early. Pure computation — no I/O.
class TerminationCalculation {
  const TerminationCalculation({
    required this.monthlyRent,
    required this.totalPaidAcrossPrepaidMonths,
    required this.paidForFinalMonth,
    required this.daysStayedFinalMonth,
    required this.earnedFinalMonth,
    required this.refundFinalMonth,
    required this.refundFutureMonths,
    required this.refundAmount,
  });

  final double monthlyRent;

  /// Every rent payment covering the current month + any future prepaid
  /// months, summed.
  final double totalPaidAcrossPrepaidMonths;

  final double paidForFinalMonth;
  final int daysStayedFinalMonth;

  /// daysStayed / daysInFinalMonth × monthlyRent.
  final double earnedFinalMonth;

  /// paidForFinalMonth − earnedFinalMonth (not floored on its own).
  final double refundFinalMonth;

  /// Sum of every payment record dated AFTER the termination month — 100%
  /// unearned, none of that time was lived.
  final double refundFutureMonths;

  /// refundFinalMonth + refundFutureMonths, floored at 0: an underpaid
  /// tenant owes nothing back through this flow, it only returns overpayment.
  final double refundAmount;
}

/// Early-termination logic. Payment records are NEVER deleted or modified;
/// the refund lives on the [LeaseTerminationRecord] instead.
abstract final class TerminationService {
  /// Computes the breakdown for terminating [person] on [terminationDate].
  ///
  /// "Current + future prepaid" = rent payments dated in the termination
  /// month or later. Future months are refunded in full; the final month is
  /// prorated by days actually lived.
  static TerminationCalculation calculate(
    Person person,
    List<Payment> payments,
    DateTime terminationDate,
  ) {
    final rentPayments = payments
        .where((p) => p.personId == person.id && p.type == PaymentType.rent)
        .toList();

    final terminationMonth = monthKey(terminationDate);
    final prepaid = rentPayments
        .where((p) =>
            p.month == terminationMonth ||
            _coversLaterMonth(p, terminationMonth))
        .toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    final totalPaid =
        prepaid.fold(0.0, (sum, p) => sum + p.amountPaid);

    // The final month's coverage: records dated IN the termination month
    // (multi-month payments create one record per calendar month).
    final paidForFinalMonth = prepaid
        .where((p) => p.month == terminationMonth)
        .fold(0.0, (sum, p) => sum + p.amountPaid);

    final daysStayed = terminationDate.day.clamp(1, _daysInMonth(terminationDate));
    final earned =
        daysStayed / _daysInMonth(terminationDate) * (person.monthlyRent ?? 0);

    final refundFinalMonth = paidForFinalMonth - earned;

    final refundFutureMonths = prepaid
        .where((p) => _coversLaterMonth(p, terminationMonth))
        .fold(0.0, (sum, p) => sum + p.amountPaid);

    final rawRefund = refundFinalMonth + refundFutureMonths;

    return TerminationCalculation(
      monthlyRent: person.monthlyRent ?? 0,
      totalPaidAcrossPrepaidMonths: totalPaid,
      paidForFinalMonth: paidForFinalMonth,
      daysStayedFinalMonth: daysStayed,
      earnedFinalMonth: earned,
      refundFinalMonth: refundFinalMonth,
      refundFutureMonths: refundFutureMonths,
      refundAmount: rawRefund < 0 ? 0 : rawRefund,
    );
  }

  static bool _coversLaterMonth(Payment p, String terminationMonth) {
    final parts = p.month.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final tParts = terminationMonth.split('-');
    final tYear = int.parse(tParts[0]);
    final tMonth = int.parse(tParts[1]);
    return year > tYear || (year == tYear && month > tMonth);
  }

  static int _daysInMonth(DateTime date) {
    final firstNext = DateTime(date.year, date.month + 1);
    return firstNext.difference(DateTime(date.year, date.month)).inDays;
  }

  /// Executes the termination: writes the [LeaseTerminationRecord], marks the
  /// tenant archived with [vacatedDate] = terminationDate and frees their
  /// bed. Existing Payment records stay byte-identical. Throws when reason ==
  /// other without a note, or for non-active tenants.
  static LeaseTerminationRecord terminate(
    JsonStore store, {
    required Person person,
    required TerminationCalculation calculation,
    required TerminationReason reason,
    String? reasonNote,
    DateTime? terminationDate,
  }) {
    if (person.status != PersonStatus.active) {
      throw const TerminationException(
          'Only an active tenant can end their tenure early.');
    }
    final note = reasonNote?.trim();
    if (reason == TerminationReason.other && (note == null || note.isEmpty)) {
      throw const TerminationException(
          'A short explanation is required when the reason is "Other".');
    }

    final day = terminationDate ?? DateTime.now();
    final record = LeaseTerminationRecord(
      id: newId(),
      personId: person.id,
      bedId: person.bedId ?? '',
      flatId: person.flatId ?? '',
      terminationDate: day,
      reason: reason,
      reasonNote: note,
      totalPaidAcrossPrepaidMonths: calculation.totalPaidAcrossPrepaidMonths,
      daysStayedFinalMonth: calculation.daysStayedFinalMonth,
      earnedFinalMonth: calculation.earnedFinalMonth,
      refundAmount: calculation.refundAmount,
    );

    store.runBatched(() {
      store.upsertTermination(record);
      store.upsertPerson(person.copyWith(
        status: PersonStatus.archived,
        statusDate: day,
        vacatedDate: day,
      ));
      final bed =
          store.beds.where((b) => b.tenantId == person.id).firstOrNull;
      if (bed != null) {
        store.upsertBed(bed.copyWith(clearTenantId: true));
      }
    });
    return record;
  }
}
