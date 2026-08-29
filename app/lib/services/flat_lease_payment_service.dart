import '../config.dart';
import '../models/lease_cheque_record.dart';
import '../models/lease_cheque_setting.dart';
import 'json_store.dart';
import '../utils/ids.dart';

/// Raised when a lease payment request is invalid.
class LeasePaymentException implements Exception {
  const LeasePaymentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Records flat lease cheque payments: appends an immutable
/// [LeaseChequeRecord] and advances the setting's `nextDueDate` by the
/// specified months (or the setting's interval if not provided) counted from
/// the ORIGINAL due date — never from today, so paying early or late does
/// not drift the schedule.
class FlatLeasePaymentService {
  const FlatLeasePaymentService(this.store);

  final JsonStore store;

  /// Rows for the due list: every cheque setting sorted by `nextDueDate`
  /// ascending. Past-due settings stay in the list (rendered as overdue).
  List<LeaseChequeSetting> dueList() {
    final settings = [...store.leaseChequeSettings];
    settings.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    return settings;
  }

  /// Marks [setting]'s current cheque as paid:
  ///  1. creates a [LeaseChequeRecord] with the entered amount/date,
  ///  2. advances `nextDueDate`:
  ///     - if [explicitNextDueDate] is provided, use it directly,
  ///     - else default to 1st day of month (current cycle month + monthsCovered) months later.
  /// Both writes happen as one batched store write. Returns the updated
  /// setting so callers can reflect the advanced due date.
  LeaseChequeSetting pay({
    required LeaseChequeSetting setting,
    required double amount,
    DateTime? paidDate,
    int? monthsCovered,
    DateTime? explicitNextDueDate,
    String? description,
  }) {
    if (amount <= 0) {
      throw const LeasePaymentException('Enter an amount greater than 0.');
    }
    final date = paidDate ?? DateTime.now();
    final record = LeaseChequeRecord(
      id: newId(),
      flatId: setting.flatId,
      ownerName: setting.ownerName,
      amount: amount,
      dueDate: setting.nextDueDate,
      paidDate: date,
      month: monthKey(setting.nextDueDate),
      description: description,
    );

    final DateTime nextDue;
    if (explicitNextDueDate != null) {
      nextDue = explicitNextDueDate;
    } else {
      final monthsToAdvance = monthsCovered ?? setting.intervalMonths;
      final interval = monthsToAdvance < 1 ? 2 : monthsToAdvance;
      // New rule: snap to 1st of month (cycle month + interval)
      final cycleMonth = DateTime(setting.nextDueDate.year, setting.nextDueDate.month, 1);
      final targetMonth = _addMonths(cycleMonth, interval);
      nextDue = DateTime(targetMonth.year, targetMonth.month, 1);
    }
    final updated = setting.copyWith(nextDueDate: nextDue);

    store.runBatched(() {
      store.upsertChequeRecord(record);
      store.upsertChequeSetting(updated);
    });
    return updated;
  }

  /// Directly edits a LeaseChequeSetting without creating a payment record.
  /// Used for correcting amount / nextDueDate / frequency after renegotiation.
  LeaseChequeSetting updateSetting(
    LeaseChequeSetting setting, {
    double? amount,
    DateTime? nextDueDate,
    int? intervalMonths,
  }) {
    final updated = setting.copyWith(
      amount: amount ?? setting.amount,
      nextDueDate: nextDueDate ?? setting.nextDueDate,
      intervalMonths: intervalMonths ?? setting.intervalMonths,
    );
    store.upsertChequeSetting(updated);
    return updated;
  }
}

/// Adds [months] to [date], handling month boundaries correctly.
DateTime _addMonths(DateTime date, int months) {
  final month = date.month + months;
  final year = date.year + (month - 1) ~/ 12;
  final normalizedMonth = (month - 1) % 12 + 1;
  // Try to keep the same day, but clamp to the last day of the target month
  final day = date.day;
  final lastDayOfMonth = DateTime(year, normalizedMonth + 1, 0).day;
  final clampedDay = day > lastDayOfMonth ? lastDayOfMonth : day;
  return DateTime(year, normalizedMonth, clampedDay);
}
