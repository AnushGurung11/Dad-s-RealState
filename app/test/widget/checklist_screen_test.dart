import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/lease_check_setting.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/notification_service.dart';

import '../helpers.dart';

void main() {
  InMemoryJsonStore storeWithFlats() {
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha House',
      address: '1 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertFlat(Flat(
      id: 'f2',
      name: 'Beta House',
      address: '2 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertCheckSetting(LeaseCheckSetting(
      id: 's1',
      flatId: 'f1',
      ownerName: 'Owner A',
      amount: 4000,
      nextDueDate: DateTime(2026, 8, 25),
    ));
    return store;
  }

  testWidgets('renders one row per flat', (tester) async {
    final store = storeWithFlats();
    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Checklist');

    expect(find.text('Alpha House'), findsOneWidget);
    expect(find.textContaining('Owner A'), findsOneWidget);
    expect(find.textContaining('AED 4000'), findsOneWidget);
    // Beta House has no setting yet: a default one is created on demand.
    expect(find.text('Beta House'), findsOneWidget);
    expect(find.textContaining('No owner set'), findsOneWidget);
    expect(store.leaseCheckSettings, hasLength(2));
  });

  testWidgets('editing amount/ownerName/date persists via fake store',
      (tester) async {
    final store = storeWithFlats();
    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Checklist');

    await tester.tap(find.text('Alpha House'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Owner name'), 'New Owner');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'), '7500');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final updated =
        store.leaseCheckSettings.firstWhere((s) => s.id == 's1');
    expect(updated.ownerName, 'New Owner');
    expect(updated.amount, 7500);
    expect(find.textContaining('New Owner'), findsOneWidget);
    expect(find.textContaining('AED 7500'), findsOneWidget);
  });

  testWidgets('editing the due date via the date picker persists',
      (tester) async {
    final store = storeWithFlats();
    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Checklist');

    await tester.tap(find.text('Alpha House'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Next due:'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final updated =
        store.leaseCheckSettings.firstWhere((s) => s.id == 's1');
    expect(updated.nextDueDate.day, 15);
  });

  testWidgets('toggling notify off cancels any scheduled notification',
      (tester) async {
    final store = storeWithFlats();
    final fake = FakeNotificationScheduler();
    await pumpApp(
      tester,
      store: store,
      notifications: NotificationService(fake),
    );
    await tapNavTab(tester, 'Checklist');

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final updated =
        store.leaseCheckSettings.firstWhere((s) => s.id == 's1');
    expect(updated.notifyEnabled, isFalse);
    expect(fake.cancelled, isNotEmpty);
    expect(fake.scheduled, isEmpty);
  });
}