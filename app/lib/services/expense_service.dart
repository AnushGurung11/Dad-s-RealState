import '../config.dart';
import '../models/expense.dart';
import 'json_store.dart';
import '../utils/ids.dart';

/// Business logic for expenses: validation, grouping, CRUD.
class ExpenseService {
  const ExpenseService(this.store);

  final JsonStore store;

  /// Adds or updates an expense. Validates category.
  Expense upsert({
    required String flatId,
    required ExpenseCategory category,
    required double amount,
    required DateTime date,
    String? note,
    String? existingId,
  }) {
    if (amount <= 0) {
      throw const ExpenseException('Amount must be greater than 0.');
    }
    final id = existingId ?? newId();
    final expense = Expense(
      id: id,
      flatId: flatId,
      category: category,
      amount: amount,
      date: date,
      note: note,
    );
    store.upsertExpense(expense);
    return expense;
  }

  /// Deletes an expense by ID.
  void delete(String expenseId) {
    store.deleteExpense(expenseId);
  }

  /// All expenses for a flat, sorted by date descending (newest first).
  List<Expense> forFlat(String flatId) {
    return store.expenses
        .where((e) => e.flatId == flatId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Expenses grouped by month (YYYY-MM), newest month first.
  /// Each group contains expenses sorted by date descending.
  Map<String, List<Expense>> groupedByMonth(String flatId) {
    final map = <String, List<Expense>>{};
    for (final e in forFlat(flatId)) {
      final month = monthKey(e.date);
      map.putIfAbsent(month, () => []).add(e);
    }
    // Sort months descending
    final sortedKeys = map.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    // Sort expenses within each month descending
    for (final k in map.keys) {
      map[k]!.sort((a, b) => b.date.compareTo(a.date));
    }
    return Map.fromEntries(sortedKeys.map((k) => MapEntry(k, map[k]!)));
  }

  /// Validates category is one of the 6 allowed.
  static bool isValidCategory(String? value) {
    if (value == null) return false;
    return ExpenseCategory.values.any((c) => c.name == value);
  }
}

/// Raised for invalid expense operations.
class ExpenseException implements Exception {
  const ExpenseException(this.message);

  final String message;

  @override
  String toString() => message;
}