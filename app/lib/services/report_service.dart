import '../config.dart';
import '../models/expense.dart';
import '../models/payment.dart';

/// A flat's financial summary for a period (month, YYYY-MM).
typedef FlatSummary = ({double income, double expenses, double net});

/// Pure financial report math. No I/O; operates on in-memory lists.
abstract final class ReportService {
  /// Income for [flatId] in [month]: sum of rent payments + deposits.
  static double flatIncome({
    required List<Payment> payments,
    required String flatId,
    required String month,
  }) {
    return payments
        .where((p) => p.flatId == flatId && p.month == month)
        .fold(0.0, (sum, p) => sum + p.amountPaid);
  }

  /// Expenses for [flatId] in [month]: sum of expense records whose date falls
  /// inside the month.
  static double flatExpenses({
    required List<Expense> expenses,
    required String flatId,
    required String month,
  }) {
    return expenses
        .where((e) => e.flatId == flatId && monthKey(e.date) == month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Net for [flatId] in [month]. May be negative.
  static double flatNet({
    required List<Payment> payments,
    required List<Expense> expenses,
    required String flatId,
    required String month,
  }) {
    return flatIncome(payments: payments, flatId: flatId, month: month) -
        flatExpenses(expenses: expenses, flatId: flatId, month: month);
  }

  /// Full summary for one flat in one month.
  static FlatSummary flatSummary({
    required List<Payment> payments,
    required List<Expense> expenses,
    required String flatId,
    required String month,
  }) {
    final income = flatIncome(payments: payments, flatId: flatId, month: month);
    final out = flatExpenses(expenses: expenses, flatId: flatId, month: month);
    return (income: income, expenses: out, net: income - out);
  }

  /// Cross-flat totals for [month] across all payments and expenses.
  static FlatSummary dashboardTotals({
    required List<Payment> payments,
    required List<Expense> expenses,
    required String month,
  }) {
    final income = payments
        .where((p) => p.month == month)
        .fold(0.0, (sum, p) => sum + p.amountPaid);
    final out = expenses
        .where((e) => monthKey(e.date) == month)
        .fold(0.0, (sum, e) => sum + e.amount);
    return (income: income, expenses: out, net: income - out);
  }

  /// Income rollup per month for [flatId], for months present in the data.
  static Map<String, double> monthlyIncome({
    required List<Payment> payments,
    required String flatId,
  }) {
    final rollup = <String, double>{};
    for (final p in payments.where((p) => p.flatId == flatId)) {
      rollup[p.month] = (rollup[p.month] ?? 0) + p.amountPaid;
    }
    return rollup;
  }
}