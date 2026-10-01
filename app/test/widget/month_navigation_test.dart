import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/config.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/screens/dashboard_screen.dart';
import 'package:lucky/screens/financial_activity_screen.dart';
import 'package:lucky/services/demo_data_service.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/month_selection.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';
import 'package:lucky/utils/format.dart';

/// Regression coverage for the original bug: after a calendar-month rollover
/// every financial screen was pinned to the live month, so past months looked
/// empty and the data seemed to have vanished.
void main() {
  late InMemoryJsonStore store;
  late MonthSelection selection;

  String monthOffsetFromNow(int offset) => monthKey(
      DateTime(DateTime.now().year, DateTime.now().month + offset, 1));

  setUp(() {
    store = InMemoryJsonStore();
    selection = MonthSelection();

    store.upsertFlat(
        Flat(id: 'f1', name: 'Alpha', address: 'A', createdAt: DateTime(2026, 1, 1)));

    // Rent in the current month and two months back.
    store.upsertPayment(Payment(
      id: 'now',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: monthOffsetFromNow(0),
      amountDue: 9000,
      amountPaid: 9000,
      type: PaymentType.rent,
    ));
    store.upsertPayment(Payment(
      id: 'past',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: monthOffsetFromNow(-2),
      amountDue: 9000,
      amountPaid: 9000,
      type: PaymentType.rent,
    ));
    store.upsertExpense(Expense(
      id: 'e_now',
      flatId: 'f1',
      category: ExpenseCategory.electricity,
      amount: 500,
      date: DateTime.now(),
    ));
    store.upsertExpense(Expense(
      id: 'e_past',
      flatId: 'f1',
      category: ExpenseCategory.maintenance,
      amount: 700,
      date: DateTime(DateTime.now().year, DateTime.now().month - 2, 12),
    ));
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      MonthScope(
        selection: selection,
        child: MaterialApp(
          theme: appLightTheme,
          builder: (context, child) => StoreScope(
            store: store,
            child: child ?? const SizedBox.shrink(),
          ),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Financial Activity', () {
    testWidgets('stepping back a month swaps the per-flat subtotals',
        (tester) async {
      await pump(tester, const FinancialActivityScreen());

      // Current month: 9,000 rent in, 500 electricity out.
      expect(find.textContaining(MonthSelection.label(monthOffsetFromNow(0))),
          findsWidgets);
      expect(find.textContaining('Expenses: ${formatMoneyShort(500)}'),
          findsWidgets);
      expect(find.textContaining('Expenses: ${formatMoneyShort(700)}'),
          findsNothing);

      await tester.tap(find.byKey(const Key('month_prev')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('month_prev')));
      await tester.pumpAndSettle();

      // Two months back: the same 9,000 rent, but a 700 maintenance bill.
      expect(find.textContaining('Expenses: ${formatMoneyShort(700)}'),
          findsWidgets);
      expect(find.textContaining('Expenses: ${formatMoneyShort(500)}'),
          findsNothing);
      expect(find.textContaining(MonthSelection.label(monthOffsetFromNow(-2))),
          findsWidgets);
    });

    testWidgets('a month with no activity reports zero', (tester) async {
      await pump(tester, const FinancialActivityScreen());

      await tester.tap(find.byKey(const Key('month_prev')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Income: ${formatMoneyShort(0)}'),
          findsWidgets);
      expect(find.textContaining('Expenses: ${formatMoneyShort(0)}'),
          findsWidgets);
    });

    testWidgets('the jump menu reaches a month two steps back in one tap',
        (tester) async {
      await pump(tester, const FinancialActivityScreen());

      await tester.tap(find.byKey(const Key('month_jump_menu')));
      await tester.pumpAndSettle();

      final target = monthOffsetFromNow(-2);
      await tester.tap(find.byKey(ValueKey('month_option_$target')));
      await tester.pumpAndSettle();

      expect(selection.month, target);
      expect(find.textContaining('Expenses: ${formatMoneyShort(700)}'),
          findsWidgets);
    });

    testWidgets('"This month" returns to the live month', (tester) async {
      await pump(tester, const FinancialActivityScreen());

      await tester.tap(find.byKey(const Key('month_prev')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('month_today')), findsOneWidget);

      await tester.tap(find.byKey(const Key('month_today')));
      await tester.pumpAndSettle();

      expect(selection.month, monthOffsetFromNow(0));
      expect(find.byKey(const Key('month_today')), findsNothing);
    });
  });

  group('Dashboard', () {
    testWidgets('the outstanding subtitle follows the selected month',
        (tester) async {
      await pump(
        tester,
        const Scaffold(body: DashboardScreen()),
      );

      expect(find.textContaining('tenants unpaid for'), findsOneWidget);

      await tester.tap(find.byKey(const Key('month_prev')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
            'tenants unpaid for ${MonthSelection.label(monthOffsetFromNow(-1))}'),
        findsOneWidget,
      );
    });

    testWidgets('Recent Transactions lists the past month\'s expense too',
        (tester) async {
      await pump(tester, const Scaffold(body: DashboardScreen()));

      // Recent Transactions spans all months, so the old expense is listed
      // without stepping — that is what makes past records reachable at a
      // glance. It sits below the fold on a short test viewport.
      await tester.scrollUntilVisible(find.text('Recent Transactions'), 200);
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('Maintenance'), findsWidgets);
    });
  });

  group('Demo data end to end', () {
    testWidgets('every seeded month opens and shows activity', (tester) async {
      store = InMemoryJsonStore();
      DemoDataService(store).seed();
      selection = MonthSelection();

      await pump(tester, const FinancialActivityScreen());

      expect(MonthSelection.monthsWithData(store).length,
          greaterThanOrEqualTo(DemoDataService.monthsOfHistory));

      for (final month in DemoDataService.coveredMonths()) {
        await tester.tap(find.byKey(const Key('month_jump_menu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('month_option_$month')));
        await tester.pumpAndSettle();

        expect(selection.month, month);
        expect(
          find.byKey(const Key('flat-summary-demo_flat_a')),
          findsOneWidget,
          reason: 'seeded flat should still be listed for $month',
        );
      }
    });
  });
}
