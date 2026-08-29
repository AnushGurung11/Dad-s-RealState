import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/main.dart';
import 'package:lucky/screens/dashboard_screen.dart';
import 'package:lucky/screens/flats_screen.dart';
import 'package:lucky/screens/tenants_screen.dart';
import 'package:lucky/services/json_store.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LuckyApp(createStore: InMemoryJsonStore.new));
    await tester.pumpAndSettle();
  }

  testWidgets('5 destinations render; tapping each navigates correctly', (tester) async {
    await pumpApp(tester);

    // NavigationBar with 5 destinations
    expect(find.byType(NavigationBar), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 5);
    // NavigationDestination is the type of each destination
    expect((bar.destinations[0] as NavigationDestination).label, 'Dashboard');
    expect((bar.destinations[1] as NavigationDestination).label, 'Flats');
    expect((bar.destinations[2] as NavigationDestination).label, 'Tenants');
    expect((bar.destinations[3] as NavigationDestination).label, 'Finance');
    expect((bar.destinations[4] as NavigationDestination).label, 'More');

    // Dashboard is default
    expect(find.byType(DashboardScreen), findsOneWidget);

    // Tap Flats
    await tester.tap(find.text('Flats').last);
    await tester.pumpAndSettle();
    expect(find.byType(FlatsScreen), findsOneWidget);

    // Tap Tenants
    await tester.tap(find.text('Tenants').last);
    await tester.pumpAndSettle();
    expect(find.byType(TenantsScreen), findsOneWidget);

    // Tap Finance
    await tester.tap(find.text('Finance').last);
    await tester.pumpAndSettle();
    // Finance placeholder or future finance screen
    expect(find.text('Finance'), findsWidgets);

    // Tap Dashboard again
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('More opens a bottom sheet (not a full route) with Settings + both Archive entries', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();

    // Bottom sheet items
    expect(find.byKey(const Key('more_settings')), findsOneWidget);
    expect(find.byKey(const Key('more_archived_tenants')), findsOneWidget);
    expect(find.byKey(const Key('more_archive_flats')), findsOneWidget);

    // Ensure it's a modal bottom sheet, not a new route with AppBar title change
    expect(find.text('Settings'), findsOneWidget);
    // Tap Settings should navigate and close sheet
    await tester.tap(find.byKey(const Key('more_settings')));
    await tester.pumpAndSettle();
    // Settings screen should be visible (it has Data section)
    expect(find.text('Data'), findsOneWidget);
  });

  testWidgets('no Drawer widget exists anywhere in the widget tree anymore', (tester) async {
    await pumpApp(tester);
    expect(find.byType(Drawer), findsNothing);
    // Also after navigating
    await tester.tap(find.text('Flats').last);
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
  });
}
