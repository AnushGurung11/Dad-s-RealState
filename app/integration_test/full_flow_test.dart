import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:renttrack/main.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'full flow: boot → add flat → add bed → add tenant → assign bed → '
      'add payment → mark paid → dashboard reflects it',
      (tester) async {
    SharedPreferences.setMockInitialValues({'currentMonth': '2026-06'});

    final tempDir = await Directory.systemTemp.createTemp('renttrack_it_');
    addTearDown(() => tempDir.delete(recursive: true));

    final store = LocalJsonStore(directory: tempDir);
    final prefs = Prefs(await SharedPreferences.getInstance());

    // Boot the real app against a temp directory.
    await tester.pumpWidget(RentTrackApp(store: store, prefs: prefs));
    await tester.pumpAndSettle();

    // --- Add a flat.
    await tester.tap(find.text('Flats').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add flat').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Flat name'), 'Sunrise Residency');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Address'), '12 Lake Road');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Sunrise Residency'), findsOneWidget);

    // --- Add a bed inside the flat.
    await tester.tap(find.text('Sunrise Residency'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add bed').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Label (e.g. Bed A1)'), 'Bed A1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Monthly rent'), '4500');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Bed A1'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // --- Add a tenant.
    await tester.tap(find.text('Tenants').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add tenant').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'), 'Ramesh Gurung');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone'), '9841000001');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Ramesh Gurung'), findsOneWidget);

    // --- Assign the tenant to the bed.
    await tester.tap(find.byIcon(Icons.link));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bed A1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bed A1'), findsOneWidget);

    // --- Add a payment for the current month.
    await tester.tap(find.text('Payments').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add payment').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<Person>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ramesh Gurung').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add').last);
    await tester.pumpAndSettle();
    expect(find.text('Ramesh Gurung'), findsOneWidget);
    expect(find.text('UNPAID'), findsOneWidget);

    // --- Mark it paid.
    await tester.tap(find.byIcon(Icons.adaptive.more));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark paid'));
    await tester.pumpAndSettle();
    expect(find.text('PAID'), findsOneWidget);
    expect(find.text('UNPAID'), findsNothing);

    // --- Dashboard reflects everything.
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    expect(find.text('Flats'), findsWidgets);
    expect(find.text('No outstanding payments for 2026-06.'), findsOneWidget);

    // --- Data was persisted to the temp directory.
    await store.flush();
    expect(store.flats, hasLength(1));
    expect(store.flats.single.name, 'Sunrise Residency');
    expect(store.beds, hasLength(1));
    expect(store.beds.single.tenantId, isNotNull);
    expect(store.people, hasLength(1));
    expect(store.people.single.bedId, isNotNull);
    expect(store.payments, hasLength(1));
    expect(store.payments.single.status, PaymentStatus.paid);

    final files = tempDir
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split(Platform.pathSeparator).last)
        .toList();
    expect(files, containsAll(['flats.json', 'beds.json', 'people.json', 'payments.json']));
  });
}