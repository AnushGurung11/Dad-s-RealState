import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:renttrack/config.dart';
import 'package:renttrack/main.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'assign flow: boot → flat with vacant bed → tap bed → fill assign form → '
      'save → bed occupied on brief → person detail shows monthlyRent, deposit '
      'and others notes',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'currentMonth': monthKey(DateTime.now())});

    final tempDir = await Directory.systemTemp.createTemp('renttrack_assign_');
    addTearDown(() => tempDir.delete(recursive: true));

    final store = LocalJsonStore(directory: tempDir);
    final prefs = Prefs(await SharedPreferences.getInstance());

    await tester.pumpWidget(RentTrackApp(store: store, prefs: prefs));
    await tester.pumpAndSettle();

    // --- Create a flat with 5 beds and set a rent on Bed 1.
    await tester.tap(find.text('Flats').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add flat').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Flat name'), 'Sunrise Residency');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Address'), '12 Lake Road');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Number of beds'), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Sunrise Residency'), findsOneWidget);

    await tester.tap(find.text('Sunrise Residency'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit bed'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Monthly rent'), '4500');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // --- Tap the vacant bed and fill the whole assign form in one action.
    await tester.tap(find.text('Bed 1'));
    await tester.pumpAndSettle();
    expect(find.text('Assign Bed 1'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'), 'Ramesh Gurung');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact'), '9841000001');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Others'), 'Vegan, night shift');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Monthly rent'), '4800');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Deposit'), '8000');
    await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
    await tester.pumpAndSettle();

    // --- The brief bed list now shows the occupant; 4 beds remain vacant.
    expect(find.text('Vacant'), findsNWidgets(4));
    expect(find.textContaining('Ramesh Gurung'), findsOneWidget);

    // --- Tap the occupied bed → person detail shows the captured values.
    await tester.tap(find.textContaining('Ramesh Gurung'));
    await tester.pumpAndSettle();
    expect(find.text('Ramesh Gurung'), findsWidgets);
    expect(find.text('AED 4800'), findsOneWidget); // monthlyRent
    expect(find.text('AED 8000'), findsOneWidget); // deposit
    expect(find.text('Vegan, night shift'), findsOneWidget); // others notes

    // --- Persisted atomically: person + assignment + deposit in one flow.
    await store.flush();
    expect(store.beds.singleWhere((b) => b.label == 'Bed 1').tenantId, isNotNull);
    final person = store.people.single;
    expect(person.name, 'Ramesh Gurung');
    expect(person.monthlyRent, 4800);
    expect(person.depositAmount, 8000);
    expect(person.others, 'Vegan, night shift');
    expect(person.vacatedDate, isNotNull);
  });
}