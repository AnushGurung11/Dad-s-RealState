import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('shows empty state with zero flats', (tester) async {
    await pumpApp(tester);
    await tapNavTab(tester, 'Flats');

    expect(find.text('No flats yet. Add your first flat to start tracking beds.'),
        findsOneWidget);
    expect(find.text('Add flat'), findsWidgets);
  });

  testWidgets('add/edit/delete a flat updates the list', (tester) async {
    await pumpApp(tester);
    await tapNavTab(tester, 'Flats');

    await tester.tap(find.widgetWithText(FilledButton, 'Add flat').first);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Flat name'), 'Sunrise Residency');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Address'), '12 Lake Road');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Residency'), findsOneWidget);
    expect(find.textContaining('12 Lake Road'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit flat'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Flat name'), 'Sunrise Towers');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Towers'), findsOneWidget);
    expect(find.text('Sunrise Residency'), findsNothing);

    await tester.tap(find.byTooltip('Delete flat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete Sunrise Towers?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Towers'), findsNothing);
    expect(find.text('No flats yet. Add your first flat to start tracking beds.'),
        findsOneWidget);
  });

  testWidgets('add/delete a bed nested under a flat', (tester) async {
    await pumpApp(tester);
    await tapNavTab(tester, 'Flats');

    await tester.tap(find.widgetWithText(FilledButton, 'Add flat').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Flat name'), 'Alpha House');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Address'), '1 Main St');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha House'));
    await tester.pumpAndSettle();

    expect(find.text('No beds in this flat yet. Add a bed to start tracking occupancy.'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add bed').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Label (e.g. Bed A1)'), 'Bed A1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Monthly rent'), '4500');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Bed A1'), findsOneWidget);
    expect(find.textContaining('Rs. 4500/month'), findsOneWidget);
    expect(find.textContaining('Vacant'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete bed'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Bed A1'), findsNothing);
  });
}
