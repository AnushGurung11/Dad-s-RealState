import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/main.dart';
import 'package:lucky/screens/flats_screen.dart';
import 'package:lucky/services/json_store.dart';

/// Pumps the app on a tall viewport so the whole drawer fits without
/// scrolling, then opens the drawer.
Future<void> openDrawer(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(LuckyApp(createStore: InMemoryJsonStore.new));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
}

Finder inDrawer(Finder matching) =>
    find.descendant(of: find.byType(Drawer), matching: matching);

void main() {
  testWidgets('drawer renders all 8 top-level entries', (tester) async {
    await openDrawer(tester);

    const labels = [
      'Dashboard',
      'Flats',
      'Tenants',
      'Payments',
      'Payment History',
      'Expenses',
      'Settings',
      'Financial Report',
    ];
    for (final label in labels) {
      expect(inDrawer(find.text(label)), findsOneWidget);
    }
  });

  testWidgets('Tenants, Payments, Payment History and Settings expand to show '
      'their sub-items when tapped', (tester) async {
    await openDrawer(tester);

    expect(inDrawer(find.text('Add tenant')), findsNothing);

    await tester.tap(inDrawer(find.text('Tenants')));
    await tester.pumpAndSettle();
    expect(inDrawer(find.text('All tenants')), findsOneWidget);
    expect(inDrawer(find.text('Add tenant')), findsOneWidget);
    expect(inDrawer(find.text('Assign')), findsOneWidget);

    await tester.tap(inDrawer(find.text('Payments')));
    await tester.pumpAndSettle();
    expect(inDrawer(find.text('Cheque Payment (Flat)')), findsOneWidget);
    expect(inDrawer(find.text('Tenant Rent Payment')), findsOneWidget);

    await tester.tap(inDrawer(find.text('Payment History')));
    await tester.pumpAndSettle();
    expect(inDrawer(find.text('Flat Lease History')), findsOneWidget);
    expect(inDrawer(find.text('Tenant Rent History')), findsOneWidget);

    await tester.tap(inDrawer(find.text('Settings')));
    await tester.pumpAndSettle();
    // Notifications were removed entirely — only Archive remains.
    expect(inDrawer(find.text('Notifications')), findsNothing);
    expect(inDrawer(find.text('Archive')), findsOneWidget);
  });

  testWidgets('Financial Report is present but disabled and does not navigate',
      (tester) async {
    await openDrawer(tester);

    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: inDrawer(find.text('Financial Report')),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.enabled, isFalse);

    await tester.tap(inDrawer(find.text('Financial Report')),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    // Still on the dashboard route.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Dashboard'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping an enabled item navigates to that route and closes the '
      'drawer', (tester) async {
    await openDrawer(tester);

    await tester.tap(inDrawer(find.text('Flats')));
    await tester.pumpAndSettle();

    // Drawer is closed: its contents are gone from the tree.
    expect(find.byType(Drawer), findsNothing);
    // AppBar title reads "Flats" and the body is the real Flats screen
    // (chunk 2 replaced the placeholder).
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Flats'),
      ),
      findsOneWidget,
    );
    expect(find.byType(FlatsScreen), findsOneWidget);
  });

  testWidgets('the currently active route shows a selected state',
      (tester) async {
    await openDrawer(tester);

    ListTile tileFor(String label) =>
        tester.widget<ListTile>(find.widgetWithText(ListTile, label));

    expect(tileFor('Dashboard').selected, isTrue);
    expect(tileFor('Flats').selected, isFalse);

    await tester.tap(inDrawer(find.text('Flats')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(tileFor('Dashboard').selected, isFalse);
    expect(tileFor('Flats').selected, isTrue);
  });
}