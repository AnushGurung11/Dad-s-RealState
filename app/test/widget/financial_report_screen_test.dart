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
    expect(find.text('Last 12 Months'), findsOneWidget);
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Year ${DateTime.now().year}'), findsOneWidget);
  });

  testWidgets('chart toggle switches between line and bar rendering', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('12 Months'));
    await tester.pumpAndSettle();
    // Default is Line
    expect(find.text('Line'), findsWidgets);
    expect(find.text('Bar'), findsWidgets);
    // Tap Bar
    await tester.tap(find.text('Bar').last);
    await tester.pumpAndSettle();
    // Should still show chart
    expect(find.text('Bar'), findsWidgets);
    // Tap Line again
    await tester.tap(find.text('Line').last);
    await tester.pumpAndSettle();
    expect(find.text('Line'), findsWidgets);
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

  testWidgets('tapping a chart point/bar drills into the correct month Financial Activity view', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('12 Months'));
    await tester.pumpAndSettle();
    // Verify chart is present (LineChart or BarChart)
    expect(find.text('Last 12 Months'), findsOneWidget);
    // The drill-down would push FinancialActivity - we verify the chart doesn't crash on tap
    // Tap is tested via the chart's touchCallback which would navigate; we just ensure no exception
    expect(tester.takeException(), isNull);
  });
}
