import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/config.dart';
import 'package:lucky/main.dart';
import 'package:lucky/navigation/routes.dart';
import 'package:lucky/services/demo_data_service.dart';
import 'package:lucky/services/expense_aggregation_service.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/month_selection.dart';
import 'package:lucky/utils/format.dart';

/// On-device verification of the month-rollover fix, driven through the real
/// app shell (which is what mounts [MonthScope]) rather than a bare screen.
///
/// Run with:
///   flutter test integration_test/month_rollover_flow_test.dart -d emulator-5554
void main() {
  String monthOffsetFromNow(int offset) => monthKey(
      DateTime(DateTime.now().year, DateTime.now().month + offset, 1));

  setUp(() {
    // Tall enough that the summary grid and the picker are both on screen.
  });

  Future<void> pumpApp(WidgetTester tester, JsonStore store) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(LuckyApp(createStore: () => store));
    await tester.pumpAndSettle();
  }

  testWidgets('a fresh install can load sample data and browse all 3 months',
      (tester) async {
    final store = InMemoryJsonStore();
    await pumpApp(tester, store);

    // Empty install: no history to lose, and the picker is present.
    expect(find.byKey(const Key('month_prev')), findsOneWidget);
    expect(find.byKey(const Key('month_next')), findsOneWidget);
    expect(store.payments, isEmpty);

    // Load sample data through Settings, exactly as a user would.
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('more_settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_load_demo_data')), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const Key('settings_load_demo_data')), 200);

    await tester.tap(find.byKey(const Key('settings_load_demo_data')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo_data_confirm')));
    await tester.pumpAndSettle();

    expect(store.flats, hasLength(3));
    expect(store.payments, isNotEmpty);

    // Back to the dashboard via the bottom nav.
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();

    // Every seeded month is reachable through the picker and shows activity.
    for (final month in DemoDataService.coveredMonths()) {
      await tester.tap(find.byKey(const Key('month_jump_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('month_option_$month')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining(MonthSelection.label(month)),
        findsWidgets,
        reason: 'dashboard should be showing $month',
      );
      if (month != monthKey(DateTime.now())) {
        expect(
          find.byKey(const Key('month_today')),
          findsOneWidget,
          reason: 'a past month should offer a way back to the live month',
        );
      }
    }
  });

  testWidgets('financial activity reports different totals per month',
      (tester) async {
    final store = InMemoryJsonStore();
    DemoDataService(store).seed();
    await pumpApp(tester, store);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.pushNamed(Routes.financialActivity);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('month_prev')), findsOneWidget);
    expect(find.byKey(const Key('flat-summary-demo_flat_a')), findsOneWidget);

    // Record the seeded flat's expense subtotal for each month. The screen's
    // total includes lease cheques as well as utility bills, so use the same
    // aggregation service it uses rather than re-deriving it.
    final totals = <String, String>{};
    for (final month in DemoDataService.coveredMonths()) {
      await tester.tap(find.byKey(const Key('month_jump_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('month_option_$month')));
      await tester.pumpAndSettle();

      final expected = ExpenseAggregationService.totalExpensesForFlat(
        flatId: 'demo_flat_a',
        month: month,
        expenses: store.expenses,
        leaseChequeRecords: store.leaseChequeRecords,
      );
      expect(expected, greaterThan(0),
          reason: 'fixture should give $month some expenses on demo_flat_a');

      final label = 'Expenses: ${formatMoneyShort(expected)}';
      expect(find.text(label), findsWidgets,
          reason: '$month should report $label');
      totals[month] = label;
    }

    // Distinct months must not all report the same number.
    expect(totals.values.toSet().length, greaterThan(1));
  });

  testWidgets('month selection is shared across screens, not per-screen',
      (tester) async {
    final store = InMemoryJsonStore();
    DemoDataService(store).seed();
    await pumpApp(tester, store);

    // Step back one month on the dashboard.
    await tester.tap(find.byKey(const Key('month_prev')));
    await tester.pumpAndSettle();

    final chosen = monthOffsetFromNow(-1);
    expect(find.textContaining(MonthSelection.label(chosen)), findsWidgets);

    // Navigate to Financial Activity: the same month should still be selected.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.pushNamed(Routes.financialActivity);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Per-Flat Breakdown — ${MonthSelection.label(chosen)}'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('month_today')), findsOneWidget);
  });

  testWidgets('tenants paid/unpaid badges follow the selected month',
      (tester) async {
    final store = InMemoryJsonStore();
    DemoDataService(store).seed();
    await pumpApp(tester, store);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.pushNamed(Routes.tenants);
    await tester.pumpAndSettle();

    // The current month has a partial payment for demo_person_b3, and the
    // oldest month predates some tenants' move-in.
    expect(find.textContaining('Paid'), findsWidgets);

    await tester.tap(find.byKey(const Key('month_prev')));
    await tester.pumpAndSettle();

    // Changing month must not crash and must keep rendering badges.
    expect(find.textContaining('tenants unpaid for'), findsNothing);
    expect(find.byKey(const Key('month_today')), findsOneWidget);
  });
}
