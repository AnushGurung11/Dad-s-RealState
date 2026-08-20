import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:renttrack/config.dart';
import 'package:renttrack/main.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/notification_service.dart';
import 'package:renttrack/services/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'checks flow: boot → create flat (auto check setting) → set amount and '
      'owner on Checklist → due on Dashboard → mark paid archives the record '
      'and advances nextDueDate',
      (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues(
        {'currentMonth': monthKey(now)});

    final tempDir = await Directory.systemTemp.createTemp('renttrack_checks_');
    addTearDown(() => tempDir.delete(recursive: true));

    final store = LocalJsonStore(directory: tempDir);
    final prefs = Prefs(await SharedPreferences.getInstance());
    final fake = FakeNotificationScheduler();

    await tester.pumpWidget(RentTrackApp(
      store: store,
      prefs: prefs,
      notifications: NotificationService(fake),
    ));
    await tester.pumpAndSettle();

    // --- Create a flat: its check setting is auto-created.
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
    expect(store.leaseChequeSettings, hasLength(1));
    final initial = store.leaseChequeSettings.single;
    expect(initial.ownerName, '');
    expect(initial.amount, 0);
    expect(
      initial.nextDueDate,
      DateTime(now.year, now.month + 2, now.day),
    );

    // --- Set amount + owner on the Checklist page, due date = today.
    await tester.tap(find.text('Checklist').last);
    await tester.pumpAndSettle();
    expect(find.text('Sunrise Residency'), findsOneWidget);
    await tester.tap(find.text('Sunrise Residency'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Owner name'), 'Govt Housing');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'), '5000');
    await tester.tap(find.textContaining('Next due:'));
    await tester.pumpAndSettle();
    await tester.tap(find
        .descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('${now.day}'),
        )
        .last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final updated = store.leaseChequeSettings.single;
    expect(updated.ownerName, 'Govt Housing');
    expect(updated.amount, 5000);
    expect(updated.nextDueDate, DateTime(now.year, now.month, now.day));

    // --- It now shows on the Dashboard under this month.
    await tester.tap(find.text('Dashboard').last);
    await tester.pumpAndSettle();
    expect(find.text('Checks due this month'), findsOneWidget);
    expect(find.text('Sunrise Residency · Govt Housing'), findsOneWidget);
    expect(find.textContaining('AED 5000'), findsOneWidget);

    // --- Mark paid: item disappears, record archived, due date advanced.
    await tester.tap(find.text('Mark paid'));
    await tester.pumpAndSettle();
    expect(find.text('Sunrise Residency · Govt Housing'), findsNothing);
    expect(store.leaseChequeRecords, hasLength(1));
    final record = store.leaseChequeRecords.single;
    expect(record.flatId, store.flats.single.id);
    expect(record.amount, 5000);
    expect(record.ownerName, 'Govt Housing');
    expect(record.month, monthKey(now));
    expect(
      store.leaseChequeSettings.single.nextDueDate,
      DateTime(now.year, now.month + 2, now.day),
    );
    // Reminder rescheduled for the new due date (3 days before, 09:00).
    expect(fake.cancelled, isNotEmpty);
    expect(fake.scheduled, hasLength(1));
    expect(
      fake.scheduled.single.when,
      DateTime(now.year, now.month + 2, now.day - 3, 9),
    );

    // --- Both new collections persisted to disk.
    await store.flush();
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
        'lease_check_settings.json',
        'lease_check_records.json',
      ]),
    );
  });
}