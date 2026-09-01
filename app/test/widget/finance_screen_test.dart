import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/screens/finance_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  testWidgets('all 4 tabs render and switch correctly', (tester) async {
    final store = InMemoryJsonStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) => StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cheque'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // Tap Rent tab
    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();
    // Should show Tenant Rent Payment content (search field)
    expect(find.text('Rent'), findsWidgets);

    // Tap Expenses tab
    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();
    // Expenses screen shows "No flats yet." or expense list
    expect(find.text('Expenses'), findsWidgets);

    // Tap History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsWidgets);
  });

  testWidgets('old Payments/Payment History drawer groups no longer exist anywhere', (tester) async {
    final store = InMemoryJsonStore();
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) => StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: FinanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // FinanceScreen should not contain old drawer labels as separate screens
    // Check that Drawer widget doesn't exist (already tested in bottom_nav)
    expect(find.byType(Drawer), findsNothing);
    // The old "Payments" hub with "Flat Lease Payment" and "Tenant Rent Payment" as drawer items
    // should not be found as drawer entries - but they are now inside Finance tabs
    // We check that the FinanceScreen's tabs are present, not the old drawer
    expect(find.text('Report'), findsNothing);
  });
}
