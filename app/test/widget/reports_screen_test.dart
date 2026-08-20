import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/expense.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/json_store.dart';

import '../helpers.dart';

void main() {
  Future<void> pumpTallApp(
    WidgetTester tester, {
    required InMemoryJsonStore store,
    required Map<String, Object> prefs,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(tester, store: store, prefs: prefs);
  }
  InMemoryJsonStore seededStore({bool negative = false}) {
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha House',
      address: '1 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertBed(const Bed(id: 'b1', flatId: 'f1', label: 'Bed A1', defaultMonthlyRent: 4000));
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      contact: '9000000001',
      bedId: 'b1',
    ));
    store.upsertPayment(const Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: '2026-06',
      amountDue: 4000,
      amountPaid: 4000,
    ));
    store.upsertPayment(const Payment(
      id: 'pay2',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: '2026-05',
      amountDue: 4000,
      amountPaid: 4000,
    ));
    store.upsertExpense(Expense(
      id: 'exp1',
      flatId: 'f1',
      category: ExpenseCategory.electricity,
      amount: negative ? 6000 : 1500,
      date: DateTime(2026, 6, 10),
    ));
    store.upsertExpense(Expense(
      id: 'exp2',
      flatId: 'f1',
      category: ExpenseCategory.water,
      amount: 500,
      date: DateTime(2026, 5, 15),
    ));
    return store;
  }

  testWidgets('shows per-flat income, expenses and net for the period',
      (tester) async {
    await pumpTallApp(tester, store: seededStore(), prefs: {'currentMonth': '2026-06'});
    await tapNavTab(tester, 'Reports');

    // June: income 4000, expenses 1500, net 2500.
    expect(find.text('AED 4000'), findsNWidgets(2)); // totals + flat card
    expect(find.text('AED 1500'), findsNWidgets(2));
    expect(find.text('AED 2500'), findsNWidgets(2));
    expect(find.text('Electricity · AED 1500'), findsOneWidget);
  });

  testWidgets('switching period recalculates the figures', (tester) async {
    await pumpTallApp(tester, store: seededStore(), prefs: {'currentMonth': '2026-06'});
    await tapNavTab(tester, 'Reports');

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();

    // May: income 4000, expenses 500, net 3500.
    expect(find.text('AED 3500'), findsNWidgets(2));
    expect(find.text('AED 1500'), findsNothing);
    expect(find.text('Water · AED 500'), findsOneWidget);
  });

  testWidgets('negative net renders as a signed negative number', (tester) async {
    await pumpTallApp(
      tester,
      store: seededStore(negative: true),
      prefs: {'currentMonth': '2026-06'},
    );
    await tapNavTab(tester, 'Reports');

    // June: income 4000, expenses 6000, net -2000.
    expect(find.text('AED -2000'), findsNWidgets(2));
    expect(find.text('AED 2000'), findsNothing);
  });

  testWidgets('adding an expense updates the report immediately',
      (tester) async {
    final store = seededStore();
    await pumpTallApp(tester, store: store, prefs: {'currentMonth': '2026-06'});
    await tapNavTab(tester, 'Reports');

    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'Add expense').first,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Add expense').first);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'), '1000');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // The new expense defaults to the report's month (June) and the default
    // category (Electricity): expenses 1500 + 1000 = 2500, net 4000 − 2500.
    expect(find.text('Electricity · AED 1000'), findsOneWidget);
    expect(find.text('AED 4000'), findsNWidgets(2)); // income
    expect(find.text('AED 2500'), findsNWidgets(2)); // expenses
    expect(find.text('AED 1500'), findsNWidgets(2)); // net
  });
}
