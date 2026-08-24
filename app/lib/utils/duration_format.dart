/// Duration formatting utilities for human-readable time differences.
library;

/// Formats a total number of days into a human-readable string showing
/// months and days, using actual calendar months from today.
///
/// Examples:
/// - 40 → "1 month 10 days"
/// - 5 → "5 days"
/// - 0 → "Due today"
/// - -5 → "Overdue by 5 days"
/// - -40 → "Overdue by 1 month 10 days"
String formatRemaining(int totalDays) {
  if (totalDays == 0) return 'Due today';

  final isOverdue = totalDays < 0;
  final absDays = totalDays.abs();

  final now = DateTime.now();
  DateTime targetDate;
  if (isOverdue) {
    targetDate = now.subtract(Duration(days: absDays));
  } else {
    targetDate = now.add(Duration(days: absDays));
  }

  int months = 0;
  int days = 0;

  if (isOverdue) {
    // Calculate months/days from targetDate to now
    months = _monthsBetween(targetDate, now);
    final afterMonths = _addMonths(targetDate, months);
    days = now.difference(afterMonths).inDays;
  } else {
    // Calculate months/days from now to targetDate
    months = _monthsBetween(now, targetDate);
    final afterMonths = _addMonths(now, months);
    days = targetDate.difference(afterMonths).inDays;
  }

  String result;
  if (months > 0 && days > 0) {
    result = '$months month${months == 1 ? '' : 's'} $days day${days == 1 ? '' : 's'}';
  } else if (months > 0) {
    result = '$months month${months == 1 ? '' : 's'}';
  } else {
    result = '$days day${days == 1 ? '' : 's'}';
  }

  if (isOverdue) {
    return 'Overdue by $result';
  }
  return result;
}

/// Calculates the number of whole calendar months between [start] and [end].
/// Returns the number of complete months (where the day of month is the same or later).
int _monthsBetween(DateTime start, DateTime end) {
  if (start.isAfter(end)) return 0;
  
  int months = (end.year - start.year) * 12 + (end.month - start.month);
  
  // If the end day is before the start day, we haven't completed the last month
  if (end.day < start.day) {
    months--;
  }
  
  return months < 0 ? 0 : months;
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