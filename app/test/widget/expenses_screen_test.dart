import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/screens/expenses_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  late InMemoryJsonStore store;

  Future<void> pumpExpenses(WidgetTester tester,
      {String? initialFlatId}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: ExpensesScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  final flatA = Flat(
    id: 'f1',
    name: 'Alpha',
    address: '1 A Road',
    createdAt: DateTime(2026, 1, 1),
  );
  final flatB = Flat(
    id: 'f2',
    name: 'Beta',
    address: '2 B Road',
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flatA);
    store.upsertFlat(flatB);
  });

  testWidgets('expenses render grouped by month, newest first', (tester) async {
    // Add expenses: Dec 2026 (2), Jan 2027 (1)
    store.upsertExpense(Expense(
      id: 'e1',
      flatId: 'f1',
      category: ExpenseCategory.electricity,
      amount: 100,
      date: DateTime(2026, 12, 1),
    ));
    store.upsertExpense(Expense(
      id: 'e2',
      flatId: 'f1',
      category: ExpenseCategory.water,
      amount: 200,
      date: DateTime(2026, 12, 28),
    ));
    store.upsertExpense(Expense(
      id: 'e3',
      flatId: 'f1',
      category: ExpenseCategory.gas,
      amount: 300,
      date: DateTime(2027, 1, 5),
    ));

    await pumpExpenses(tester);

    // Jan 2027 should appear before Dec 2026
    final janIdx = tester.getTopLeft(find.text('Jan 2027')).dy;
    final decIdx = tester.getTopLeft(find.text('Dec 2026')).dy;
    expect(janIdx, lessThan(decIdx));

    // Within Dec, 28th before 1st
    final dec28 = tester.getTopLeft(find.text('2026-12-28')).dy;
    final dec1 = tester.getTopLeft(find.text('2026-12-01')).dy;
    expect(dec28, lessThan(dec1));
  });

  testWidgets('adding an expense updates the list immediately', (tester) async {
    await pumpExpenses(tester);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '500');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.textContaining('500'), findsOneWidget);
    expect(store.expenses, hasLength(1));
  });

  testWidgets('editing an expense persists and reflects without reload', (tester) async {
    store.upsertExpense(Expense(
      id: 'e1',
      flatId: 'f1',
      category: ExpenseCategory.electricity,
      amount: 100,
      date: DateTime(2026, 5, 10),
    ));

    await pumpExpenses(tester);

    // Tap the expense tile to edit
    await tester.tap(find.text('AED 100'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '250');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('AED 250'), findsOneWidget);
    expect(find.text('AED 100'), findsNothing);
    expect(store.expenses.single.amount, 250);
  });

  testWidgets('deleting an expense removes it and shows empty state', (tester) async {
    store.upsertExpense(Expense(
      id: 'e1',
      flatId: 'f1',
      category: ExpenseCategory.electricity,
      amount: 100,
      date: DateTime(2026, 5, 10),
    ));

    await pumpExpenses(tester);

    // Open menu and delete
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No expenses for Alpha yet.'), findsOneWidget);
    expect(store.expenses, isEmpty);
  });
}