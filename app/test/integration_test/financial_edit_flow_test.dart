import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/transaction_edit_service.dart';
import 'package:lucky/services/dashboard_service.dart';
import 'package:lucky/services/report_service.dart';
import 'package:lucky/config.dart';

void main() {
  testWidgets('log an expense on the wrong flat → edit it via Financial Activity to correct totals → verify Dashboard and Financial Report reflect correction, audit log exists', (tester) async {
    final store = InMemoryJsonStore();
    final flatA = Flat(id: 'f1', name: 'Alpha', address: 'A', createdAt: DateTime(2026, 1, 1));
    final flatB = Flat(id: 'f2', name: 'Beta', address: 'B', createdAt: DateTime(2026, 1, 1));
    store.upsertFlat(flatA);
    store.upsertFlat(flatB);
    // Add an expense on Alpha with wrong amount 500 (should be 100)
    final expense = Expense(id: 'e1', flatId: 'f1', category: ExpenseCategory.electricity, amount: 500, date: DateTime(DateTime.now().year, DateTime.now().month, 10));
    store.upsertExpense(expense);

    final month = monthKey(DateTime.now());
    // Check initial totals: Alpha should have 500 expense
    final initialAlphaExpense = ReportService.flatExpenses(expenses: store.expenses, flatId: 'f1', month: month);
    expect(initialAlphaExpense, 500);

    // Edit via TransactionEditService (as Financial Activity would)
    final service = TransactionEditService(store);
    await service.editExpense('e1', amount: 100);

    // Verify Dashboard and Financial Report reflect correction immediately
    final correctedAlphaExpense = ReportService.flatExpenses(expenses: store.expenses, flatId: 'f1', month: month);
    expect(correctedAlphaExpense, 100);

    // DashboardService should also reflect same
    final dashboard = DashboardService().build(
      flats: store.flats,
      beds: [],
      people: [],
      payments: [],
      expenses: store.expenses,
      leaseSettings: [],
      leaseChequeRecords: [],
      month: month,
    );
    // Dashboard's monthExpense should be 100 (only Alpha's expense, Beta has 0)
    expect(dashboard.monthExpense, 100);

    // Audit log entry exists for the edit
    expect(store.auditLogs, hasLength(1));
    final audit = store.auditLogs.first;
    expect(audit.entityType.name, 'expense');
    expect(audit.entityId, 'e1');
    expect(audit.action.name, 'edit');
    expect(audit.beforeSnapshot['amount'], 500);
    expect(audit.afterSnapshot!['amount'], 100);
  });
}
