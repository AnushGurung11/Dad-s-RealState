import '../config.dart';
import '../models/lease_check_record.dart';
import '../models/lease_check_setting.dart';
import '../utils/ids.dart';

/// Pure logic for recurring lease checks (money paid out to the flat owner).
/// No I/O — callers persist the returned data.
class CheckService {
  /// Checks whose [LeaseCheckSetting.nextDueDate] falls in the current or next
  /// calendar month relative to [today], sorted by due date.
  static List<LeaseCheckSetting> dueThisAndNextMonth(
    List<LeaseCheckSetting> settings,
    DateTime today,
  ) {
    final current = monthKey(today);
    final next = monthKey(DateTime(today.year, today.month + 1, 1));
    final due = settings
        .where((s) {
          final key = monthKey(s.nextDueDate);
          return key == current || key == next;
        })
        .toList()
      ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
    return due;
  }

  /// Marks a check paid: archives it as an immutable [LeaseCheckRecord] and
  /// returns the updated setting with [nextDueDate] advanced by
  /// [intervalMonths]. Never mutates prior records.
  static ({LeaseCheckRecord record, LeaseCheckSetting setting}) markPaid(
    LeaseCheckSetting setting,
    DateTime today,
  ) {
    final advanced = DateTime(
      setting.nextDueDate.year,
      setting.nextDueDate.month + setting.intervalMonths,
      setting.nextDueDate.day,
    );
    return (
      record: LeaseCheckRecord(
        id: newId(),
        flatId: setting.flatId,
        ownerName: setting.ownerName,
        amount: setting.amount,
        dueDate: setting.nextDueDate,
        paidDate: today,
        month: monthKey(setting.nextDueDate),
      ),
      setting: setting.copyWith(nextDueDate: advanced),
    );
  }
}