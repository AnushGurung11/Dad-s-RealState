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
/// [LeaseChequeRecord] and advances the setting's `nextDueDate` by its
/// interval counted from the ORIGINAL due date — never from today, so paying
/// early or late does not drift the schedule.
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
  ///  2. advances `nextDueDate` by the interval from the original due date.
  /// Both writes happen as one batched store write. Returns the updated
  /// setting so the caller can reschedule its notification.
  LeaseChequeSetting pay({
    required LeaseChequeSetting setting,
    required double amount,
    DateTime? paidDate,
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
    );

    // Advance from the ORIGINAL due date, not from today.
    final interval =
        setting.intervalMonths < 1 ? 2 : setting.intervalMonths;
    final original = setting.nextDueDate;
    final nextDue = DateTime(
      original.year,
      original.month + interval,
      original.day,
    );
    final updated = setting.copyWith(nextDueDate: nextDue);

    store.runBatched(() {
      store.upsertChequeRecord(record);
      store.upsertChequeSetting(updated);
    });
    return updated;
  }
}
