import '../config.dart';
import '../models/expense.dart';
import '../models/lease_cheque_record.dart';

/// Single shared function for total expenses per flat per month.
/// Combines categorized Expenses and LeaseChequeRecords so every
/// financial view (Dashboard, Profit breakdown, Financial Report) agrees.
class ExpenseAggregationService {
  const ExpenseAggregationService._();

  /// Total expenses for [flatId] in [month] (YYYY-MM).
  /// Sums both Expense records and LeaseChequeRecords for that flat/month.
  static double totalExpensesForFlat({
    required String flatId,
    required String month,
    required List<Expense> expenses,
    required List<LeaseChequeRecord> leaseChequeRecords,
  }) {
    final expenseSum = expenses
        .where((e) => e.flatId == flatId && monthKey(e.date) == month)
        .fold(0.0, (sum, e) => sum + e.amount);
    final leaseSum = leaseChequeRecords
        .where((r) => r.flatId == flatId && r.month == month)
        .fold(0.0, (sum, r) => sum + r.amount);
    return expenseSum + leaseSum;
  }

  /// Cross-flat total for a month (all flats).
  static double totalExpensesForMonth({
    required String month,
    required List<Expense> expenses,
    required List<LeaseChequeRecord> leaseChequeRecords,
  }) {
    final expenseSum = expenses
        .where((e) => monthKey(e.date) == month)
        .fold(0.0, (sum, e) => sum + e.amount);
    final leaseSum = leaseChequeRecords
        .where((r) => r.month == month)
        .fold(0.0, (sum, r) => sum + r.amount);
    return expenseSum + leaseSum;
  }
}
