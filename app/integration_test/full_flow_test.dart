import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:renttrack/config.dart';
import 'package:renttrack/main.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'full flow: boot → create flat with 6 beds → assign tenant from a vacant '
      'bed with deposit → add rent payment → add expense → report matches',
      (tester) async {
    final currentMonth = monthKey(DateTime.now());
    SharedPreferences.setMockInitialValues({'currentMonth': currentMonth});

    final tempDir = await Directory.systemTemp.createTemp('renttrack_it_');
    addTearDown(() => tempDir.delete(recursive: true));

    final store = LocalJsonStore(directory: tempDir);
    final prefs = Prefs(await SharedPreferences.getInstance());

    // Boot the real app against a temp directory.
    await tester.pumpWidget(RentTrackApp(store: store, prefs: prefs));
    await tester.pumpAndSettle();

    // --- Create a flat with 6 beds (within the 5-20 rule).
    await tester.tap(find.text('Flats').last);
    await tester.pumpAndSettle();
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

    // --- Set a rent on Bed 1 so payments have a real due amount.
    await tester.tap(find.text('Sunrise Residency'));
    await tester.pumpAndSettle();
    expect(find.text('6 / 20 beds'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit bed'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Monthly rent'), '4500');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // --- Single-step assign: tap the vacant Bed 1 and fill the assign form.
    await tester.tap(find.text('Bed 1'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'), 'Ramesh Gurung');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact'), '9841000001');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Deposit'), '10000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Planned stay (months)'), '3');
    await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
    await tester.pumpAndSettle();

    // --- Open the tenant's history from the occupied bed row.
    await tester.tap(find.textContaining('Ramesh Gurung'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Balance'), findsOneWidget);

    // --- Add a rent payment from the person's history.
    await tester.tap(find.text('Ramesh Gurung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add payment'));
    await tester.pumpAndSettle();
    // Amount due pre-fills from the bed rent (4500); pay it in full.
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount paid (optional)'), '4500');
    await tester.tap(find.widgetWithText(FilledButton, 'Add').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Rent'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // --- Add an expense in the reports tab.
    await tester.tap(find.text('Reports').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Add expense').first);
    await tester.tap(find.widgetWithText(TextButton, 'Add expense').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Amount'), '2000');
    await tester.tap(find.widgetWithText(FilledButton, 'Add').last);
    await tester.pumpAndSettle();
    expect(find.text('Other · AED 2000'), findsOneWidget);

    // --- Report matches: income = deposit 10000 + rent 4500, expenses = 2000,
    // net = 12500.
    expect(find.text('AED 14500'), findsNWidgets(2));
    expect(find.text('AED 2000'), findsNWidgets(2));
    expect(find.text('AED 12500'), findsNWidgets(2));

    // --- Data persisted to the temp directory.
    await store.flush();
    expect(store.flats, hasLength(1));
    expect(store.flats.single.name, 'Sunrise Residency');
    expect(store.beds, hasLength(6));
    expect(store.beds.singleWhere((b) => b.label == 'Bed 1').tenantId, isNotNull);
    expect(store.people, hasLength(1));
    expect(store.people.single.bedId, isNotNull);
    expect(store.people.single.depositAmount, 10000);
    expect(store.people.single.plannedStayMonths, 3);
    expect(store.people.single.vacatedDate, isNotNull);
    expect(store.payments, hasLength(2));
    expect(
      store.payments.where((p) => p.type == PaymentType.deposit),
      hasLength(1),
    );
    expect(
      store.payments.singleWhere((p) => p.type == PaymentType.rent).amountPaid,
      4500,
    );
    expect(store.expenses, hasLength(1));
    expect(store.expenses.single.amount, 2000);

    final files = tempDir
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split(Platform.pathSeparator).last)
        .toList();
    expect(
      files,
      containsAll([
        'flats.json',
        'beds.json',
        'people.json',
        'payments.json',
        'expenses.json',
      ]),
    );
  });
}