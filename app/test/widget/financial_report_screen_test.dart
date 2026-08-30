import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/screens/financial_report_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';
import 'package:lucky/config.dart';

void main() {
  late InMemoryJsonStore store;

  final flatA = Flat(id: 'f1', name: 'Alpha', address: 'A', createdAt: DateTime(2026, 1, 1));

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flatA);
    store.upsertPayment(Payment(id: 'p1', personId: 'p1', bedId: 'b1', flatId: 'f1', month: monthKey(DateTime.now()), amountDue: 1000, amountPaid: 1000, type: PaymentType.rent));
    store.upsertExpense(Expense(id: 'e1', flatId: 'f1', category: ExpenseCategory.electricity, amount: 100, date: DateTime.now()));
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) => StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: FinancialReportScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('scope selector switches between This Month / 12 Months / Yearly correctly', (tester) async {
    await pumpScreen(tester);
    expect(find.text('This Month'), findsOneWidget);
    await tester.tap(find.text('12 Months'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Last 12 Months'), findsOneWidget);
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Year ${DateTime.now().year}'), findsOneWidget);
  });

  testWidgets('table view shows reliable financial records instead of charts', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('12 Months'));
    await tester.pumpAndSettle();
    // Should show table, not charts
    expect(find.textContaining('Last 12 Months'), findsOneWidget);
    expect(find.textContaining('Detailed Table'), findsOneWidget);
    // DataTable should be present with Income/Expense/Net headers
    expect(find.text('Income'), findsWidgets);
    expect(find.text('Expense'), findsWidgets);
    expect(find.text('Net'), findsWidgets);
    // No Line/Bar toggle should exist (charts removed)
    expect(find.text('Line'), findsNothing);
    expect(find.text('Bar'), findsNothing);
  });

  testWidgets('flat filter changes displayed data correctly', (tester) async {
    await pumpScreen(tester);
    // All flats vs Alpha
    expect(find.text('All flats'), findsOneWidget);
    await tester.tap(find.text('All flats'));
    await tester.pumpAndSettle();
    // Should show flat picker
    expect(find.text('Alpha'), findsWidgets);
  });

  testWidgets('table view renders without exception and shows transaction ledger', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('12 Months'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Last 12 Months'), findsOneWidget);
    expect(find.textContaining('Transaction Ledger'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
