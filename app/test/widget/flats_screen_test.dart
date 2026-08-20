import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/lease_cheque_setting.dart';
import 'package:renttrack/services/bed_capacity_service.dart';
import 'package:renttrack/services/json_store.dart';

import '../helpers.dart';

void main() {
  InMemoryJsonStore storeWithFlat(int bedCount) {
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha House',
      address: '1 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    for (var i = 1; i <= bedCount; i++) {
      store.upsertBed(Bed(
        id: 'b$i',
        flatId: 'f1',
        label: 'Bed $i',
        defaultMonthlyRent: 4000,
      ));
    }
    return store;
  }

  testWidgets('shows empty state with zero flats', (tester) async {
    await pumpApp(tester);
    await tapNavTab(tester, 'Flats');

    expect(find.text('No flats yet. Add your first flat to start tracking beds.'),
        findsOneWidget);
    expect(find.text('Add flat'), findsWidgets);
  });

  testWidgets('flat creation form rejects <5 or >20 beds requested',
      (tester) async {
    await pumpApp(tester);
    await tapNavTab(tester, 'Flats');

    await tester.tap(find.widgetWithText(FilledButton, 'Add flat').first);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Flat name'), 'Sunrise Residency');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Address'), '12 Lake Road');

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Number of beds'), '4');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Beds must be between 5 and 20'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Number of beds'), '21');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Beds must be between 5 and 20'), findsOneWidget);

    // A valid count still submits.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Number of beds'), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Sunrise Residency'), findsOneWidget);
  });

  testWidgets('add/edit/delete a flat; creation auto-creates the requested beds',
      (tester) async {
    await pumpApp(tester);
    await tapNavTab(tester, 'Flats');

    await tester.tap(find.widgetWithText(FilledButton, 'Add flat').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Flat name'), 'Sunrise Residency');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Address'), '12 Lake Road');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Number of beds'), '6');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Residency'), findsOneWidget);
    expect(find.text('0 / 6 beds'), findsOneWidget);

    // Open the flat: six auto-created beds and the capacity hint.
    await tester.tap(find.text('Sunrise Residency'));
    await tester.pumpAndSettle();
    expect(find.text('6 / 20 beds'), findsOneWidget);
    expect(find.text('Bed 1'), findsOneWidget);
    expect(find.text('Bed 6'), findsOneWidget);

    // Edit the flat from the detail screen's app bar.
    await tester.tap(find.byTooltip('Edit flat'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Flat name'), 'Sunrise Towers');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Towers'), findsOneWidget);
    expect(find.text('Sunrise Residency'), findsNothing);

    // Delete the flat from the detail screen's app bar.
    await tester.tap(find.byTooltip('Delete flat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete Sunrise Towers?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Towers'), findsNothing);
    expect(find.text('No flats yet. Add your first flat to start tracking beds.'),
        findsOneWidget);
  });

  testWidgets('add bed is disabled with an explanation at 20 beds',
      (tester) async {
    await pumpApp(tester, store: storeWithFlat(20));
    await tapNavTab(tester, 'Flats');
    await tester.tap(find.text('Alpha House'));
    await tester.pumpAndSettle();

    expect(find.text('20 / 20 beds'), findsOneWidget);

    await tester.tap(find.text('Full at 20'));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Cannot add a bed: this flat already has ${BedCapacityService.maxBeds} beds (the maximum).'),
      findsOneWidget,
    );
    // No add-bed form opened.
    expect(find.text('Add bed'), findsNothing);
  });

  testWidgets('delete bed is disabled with an explanation at 5 beds',
      (tester) async {
    await pumpApp(tester, store: storeWithFlat(5));
    await tapNavTab(tester, 'Flats');
    await tester.tap(find.text('Alpha House'));
    await tester.pumpAndSettle();

    expect(find.text('5 / 20 beds'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete bed').first);
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Cannot delete a bed: a flat must keep at least ${BedCapacityService.minBeds} beds.'),
      findsOneWidget,
    );
    // No confirmation dialog opened.
    expect(find.textContaining('Delete Bed 1?'), findsNothing);
  });

  testWidgets('yearly rent auto-fills the cheque amount as yearlyRent / 6',
      (tester) async {
    final store = InMemoryJsonStore();
    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Flats');

    await tester.tap(find.widgetWithText(FilledButton, 'Add flat').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Flat name'), 'Sunrise Residency');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Address'), '12 Lake Road');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Number of beds'), '5');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Yearly rent'), '24000');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Sunrise Residency'), findsOneWidget);
    final setting = store.leaseChequeSettings.single;
    expect(setting.amount, 4000);
    expect(setting.ownerName, '');
  });

  testWidgets('brief card shows a "Cheque in Xd" badge when due within 3 days',
      (tester) async {
    final store = storeWithFlat(5);
    final now = DateTime.now();
    store.upsertChequeSetting(LeaseChequeSetting(
      id: 's1',
      flatId: 'f1',
      ownerName: 'Owner',
      amount: 4000,
      nextDueDate: DateTime(now.year, now.month, now.day + 2),
    ));

    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Flats');

    expect(find.text('Cheque in 2d'), findsOneWidget);
  });
}