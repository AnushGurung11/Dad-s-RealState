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

/// One row of a multi-month payment preview: which calendar month it lands
/// in and how much will be recorded for it.
class PlannedMonthPayment {
  const PlannedMonthPayment({required this.date, required this.amount});

  /// The 1st of the covered calendar month (month 0 keeps the entered date).
  final DateTime date;
  final double amount;

  String get month => monthKey(date);
}

/// Records tenant rent payments into the shared ledger, including
/// multi-month prepayments. Balances are never stored — [TenureService]
/// recalculates them on read from these records.
class TenantRentPaymentService {
  const TenantRentPaymentService(this.store);

  final JsonStore store;

  /// Tenants that can receive a rent payment: active and currently assigned.
  /// Sorted by name for stable lists.
  List<Person> payablePeople() {
    return store.people
        .where((p) =>
            p.isActiveTenant && p.status == PersonStatus.active)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Whether the tenant has any rent record dated in [month] — drives the
  /// Paid/Unpaid badge.
  static bool hasPaidForMonth(
      List<Payment> payments, String personId, String month) {
    return payments.any((p) =>
        p.personId == personId &&
        p.type == PaymentType.rent &&
        p.month == month &&
        p.amountPaid > 0);
  }

  /// Builds the per-month plan the form previews: month 0 on [firstDate]
  /// with [firstAmount]; months 1..n-1 on the 1st of their calendar month,
  /// defaulting to [person.monthlyRent] but editable via [futureAmounts].
  static List<PlannedMonthPayment> planMonths({
    required Person person,
    required int monthsPaying,
    required double firstAmount,
    required DateTime firstDate,
    Map<int, double>? futureAmounts,
  }) {
    if (monthsPaying < 1) {
      throw const PaymentException('Pay for at least 1 month.');
    }
    if (firstAmount <= 0) {
      throw const PaymentException('Enter an amount greater than 0.');
    }
    final defaultRent = person.monthlyRent ?? 0;
    return List.generate(monthsPaying, (index) {
      if (index == 0) {
        return PlannedMonthPayment(date: firstDate, amount: firstAmount);
      }
      final monthStart = DateTime(firstDate.year, firstDate.month + index);
      return PlannedMonthPayment(
        date: monthStart,
        amount: futureAmounts?[index] ?? defaultRent,
      );
    });
  }

  /// Creates a single rent [Payment] for [person]. The payment's month comes
  /// from the (optionally back-dated) paid date. Throws [PaymentException]
  /// for non-positive amounts or inactive tenants.
  Payment recordRent({
    required Person person,
    required double amountPaid,
    DateTime? paidDate,
    double? amountDue,
  }) {
    final date = paidDate ?? DateTime.now();
    final records = recordMultiMonthPayment(
      person: person,
      monthsPaying: 1,
      firstAmount: amountPaid,
      firstDate: date,
      firstAmountDue: amountDue,
    );
    return records.single;
  }

  /// Creates [monthsPaying] rent Payments in ONE atomic store write:
  ///  * month 0 → dated [firstDate] as entered, amount [firstAmount].
  ///  * months 1..n-1 → dated the 1st of each future calendar month, amount
  ///    defaulting to `person.monthlyRent` unless overridden per month via
  ///    [futureAmounts] (the form lets the landlord adjust each one).
  ///
  /// Nothing is silently locked to the default — every future amount is
  /// visible and editable before save.
  List<Payment> recordMultiMonthPayment({
    required Person person,
    required int monthsPaying,
    required double firstAmount,
    required DateTime firstDate,
    double? firstAmountDue,
    Map<int, double>? futureAmounts,
  }) {
    if (!person.isActiveTenant || person.isArchived) {
      throw const PaymentException('Only active tenants can be paid.');
    }
    final planned = planMonths(
      person: person,
      monthsPaying: monthsPaying,
      firstAmount: firstAmount,
      firstDate: firstDate,
      futureAmounts: futureAmounts,
    );
    for (final month in planned.skip(1)) {
      if (month.amount <= 0) {
        throw const PaymentException(
            'Every month needs an amount greater than 0.');
      }
    }

    final records = <Payment>[];
    for (var i = 0; i < planned.length; i++) {
      final plan = planned[i];
      records.add(Payment(
        id: newId(),
        personId: person.id,
        bedId: person.bedId ?? '',
        flatId: person.flatId ?? '',
        month: plan.month,
        amountDue:
            i == 0 ? (firstAmountDue ?? person.monthlyRent ?? 0) : plan.amount,
        amountPaid: plan.amount,
        type: PaymentType.rent,
      ));
    }

    // One atomic write for the whole prepayment.
    store.runBatched(() {
      for (final record in records) {
        store.upsertPayment(record);
      }
    });
    return records;
  }
}
