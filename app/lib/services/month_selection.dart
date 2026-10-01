import 'package:flutter/widgets.dart';

import '../config.dart';
import 'json_store.dart';

/// App-wide "which month are the month-scoped views showing?" selection.
///
/// Every financial figure in the app is bucketed by a `YYYY-MM` key, so a
/// single selection keeps the Dashboard, Profit Overview, Financial Activity,
/// Financial Report and the tenant Paid/Unpaid badges all talking about the
/// same period. It starts on the current calendar month and can be walked
/// backwards, which is what makes a past month reachable at all.
///
/// Held in memory only: every launch opens on the live month rather than a
/// stale one left over from a previous session.
class MonthSelection extends ChangeNotifier {
  MonthSelection({String? initialMonth})
      : _month = normalize(initialMonth ?? monthKey(DateTime.now()));

  String _month;

  /// The selected month as `YYYY-MM`.
  String get month => _month;

  /// Whether the selection is the live calendar month.
  bool get isCurrentMonth => _month == monthKey(DateTime.now());

  /// Human label for [month], e.g. `Sep 2026`.
  static String label(String month) {
    final parsed = parse(month);
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${names[parsed.month - 1]} ${parsed.year}';
  }

  /// Parses a `YYYY-MM` key into a [DateTime] pinned to the 1st. Falls back
  /// to the current month for anything malformed rather than throwing.
  static DateTime parse(String month) {
    final match = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(month.trim());
    if (match == null) return DateTime(DateTime.now().year, DateTime.now().month, 1);
    final year = int.parse(match.group(1)!);
    final monthNo = int.parse(match.group(2)!);
    if (monthNo < 1 || monthNo > 12) {
      return DateTime(DateTime.now().year, DateTime.now().month, 1);
    }
    return DateTime(year, monthNo, 1);
  }

  /// Coerces arbitrary input into a canonical `YYYY-MM` key.
  static String normalize(String month) => monthKey(parse(month));

  void select(String month) {
    final next = normalize(month);
    if (next == _month) return;
    _month = next;
    notifyListeners();
  }

  /// Moves the selection by [delta] months (negative walks into the past).
  void step(int delta) {
    final current = parse(_month);
    select(monthKey(DateTime(current.year, current.month + delta, 1)));
  }

  void previous() => step(-1);

  void next() => step(1);

  /// Snaps back to the live calendar month.
  void reset() => select(monthKey(DateTime.now()));

  /// Every month that actually holds data in [store] — rent/deposit payments,
  /// expenses and paid lease cheques — newest first, always including the
  /// current month. Drives the "jump to a month" menu so a user never has to
  /// step backwards one month at a time hunting for old records.
  static List<String> monthsWithData(JsonStore store) {
    final months = <String>{monthKey(DateTime.now())};
    for (final payment in store.payments) {
      months.add(normalize(payment.month));
    }
    for (final expense in store.expenses) {
      months.add(monthKey(expense.date));
    }
    for (final record in store.leaseChequeRecords) {
      months.add(record.month);
    }
    final sorted = months.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }
}

/// Provides the [MonthSelection] to the widget tree, mirroring [StoreScope].
///
/// [monthOf] degrades to the current calendar month when no scope is mounted,
/// so a screen pumped on its own (widget tests) keeps working unchanged.
class MonthScope extends InheritedNotifier<MonthSelection> {
  const MonthScope({
    super.key,
    required MonthSelection selection,
    required super.child,
  }) : super(notifier: selection);

  /// The selection controller, or `null` when no [MonthScope] is mounted.
  static MonthSelection? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MonthScope>()?.notifier;

  /// The selected month, falling back to the current calendar month.
  static String monthOf(BuildContext context) =>
      maybeOf(context)?.month ?? monthKey(DateTime.now());
}
