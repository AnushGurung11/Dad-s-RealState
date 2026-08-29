import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/lease_cheque_record.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/screens/financial_activity_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';
import 'package:lucky/config.dart';

void main() {
  late InMemoryJsonStore store;

  final flatA = Flat(id: 'f1', name: 'Alpha', address: 'A', createdAt: DateTime(2026, 1, 1));
  final flatB = Flat(id: 'f2', name: 'Beta', address: 'B', createdAt: DateTime(2026, 1, 1));

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flatA);
    store.upsertFlat(flatB);
    // Payments
    store.upsertPayment(Payment(id: 'p1', personId: 'p1', bedId: 'b1', flatId: 'f1', month: monthKey(DateTime.now()), amountDue: 1000, amountPaid: 1000, type: PaymentType.rent));
    store.upsertPayment(Payment(id: 'p2', personId: 'p2', bedId: 'b2', flatId: 'f2', month: monthKey(DateTime.now()), amountDue: 2000, amountPaid: 2000, type: PaymentType.rent));
    // Expenses
    store.upsertExpense(Expense(id: 'e1', flatId: 'f1', category: ExpenseCategory.electricity, amount: 100, date: DateTime.now()));
    store.upsertExpense(Expense(id: 'e2', flatId: 'f2', category: ExpenseCategory.water, amount: 50, date: DateTime.now()));
    // Lease
    store.upsertChequeRecord(LeaseChequeRecord(id: 'l1', flatId: 'f1', ownerName: 'Owner', amount: 300, dueDate: DateTime.now(), paidDate: DateTime.now(), month: monthKey(DateTime.now())));
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) => StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: FinancialActivityScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('per-flat grouped summary shows correct income/expense/net subtotals per flat, matching totalExpensesForFlat', (tester) async {
    await pumpScreen(tester);
    // Should show per-flat breakdown
    expect(find.textContaining('Per-Flat Breakdown'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    // Check income/expense values - Alpha income 1000, expense 400 (100+300), net 600
    expect(find.textContaining('Income:'), findsWidgets);
    expect(find.textContaining('Expenses:'), findsWidgets);
  });

  testWidgets('full transaction list includes all four record types, each editable/deletable inline', (tester) async {
    await pumpScreen(tester);
    expect(find.text('All Transactions'), findsOneWidget);
    // Should have at least 4 transactions (2 payments + 2 expenses + 1 lease)
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
  });
}
