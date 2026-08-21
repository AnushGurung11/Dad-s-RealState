import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/lease_cheque_setting.dart';
import 'package:renttrack/screens/flat_lease_payment_screen.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/notification_service.dart';
import 'package:renttrack/services/prefs.dart';
import 'package:renttrack/services/store_scope.dart';
import 'package:renttrack/theme/app_theme.dart';
import 'package:renttrack/utils/format.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records scheduling calls instead of touching platform channels.
class SpyScheduler implements NotificationScheduler {
  final List<DateTime> scheduled = [];
  final List<int> cancelledIds = [];

  @override
  Future<void> scheduleAt({
    required DateTime when,
    required int id,
    required String title,
    required String body,
  }) async {
    scheduled.add(when);
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }
}

void main() {
  late InMemoryJsonStore store;
  late Prefs prefs;

  final flatA = Flat(
    id: 'f1',
    name: 'Alpha',
    address: '1 A Road',
    createdAt: DateTime(2026, 1, 1),
  );
  final flatB = Flat(
    id: 'f2',
    name: 'Beta',
    address: '2 B Road',
    createdAt: DateTime(2026, 1, 1),
  );

  LeaseChequeSetting setting({
    String id = 's1',
    required String flatId,
    required DateTime nextDueDate,
  }) =>
      LeaseChequeSetting(
        id: id,
        flatId: flatId,
        ownerName: 'Owner',
        amount: 4000,
        nextDueDate: nextDueDate,
        notifyEnabled: true,
      );

  Future<void> pumpScreen(
    WidgetTester tester, {
    NotificationService? notificationService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          body: FlatLeasePaymentScreen(
            notificationService: notificationService,
            prefs: prefs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = Prefs(await SharedPreferences.getInstance());
    store = InMemoryJsonStore();
    store.upsertFlat(flatA);
    store.upsertFlat(flatB);
  });

  testWidgets('rows are sorted by due date ascending', (tester) async {
    final now = DateTime.now();
    store.upsertChequeSetting(setting(
        id: 's1', flatId: 'f2', nextDueDate: now.add(const Duration(days: 40))));
    store.upsertChequeSetting(setting(
        id: 's2', flatId: 'f1', nextDueDate: now.add(const Duration(days: 10))));

    await pumpScreen(tester);

    double topOf(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(topOf('Alpha'), lessThan(topOf('Beta')));
  });

  testWidgets('overdue rows are styled with the danger color', (tester) async {
    store.upsertChequeSetting(setting(
        id: 's3',
        flatId: 'f1',
        nextDueDate: DateTime.now().subtract(const Duration(days: 5))));

    await pumpScreen(tester);

    final danger =
        appLightTheme.extension<AppStatusColors>()!.danger;
    final text = tester.widget<Text>(find.text('5 days overdue'));
    expect(text.style?.color, danger);
  });

  testWidgets('pay flow records the payment and advances the row to the new '
      'due date', (tester) async {
    final due = DateTime(2026, 10, 25);
    store.upsertChequeSetting(setting(id: 's1', flatId: 'f1', nextDueDate: due));

    final spy = SpyScheduler();
    await pumpScreen(tester, notificationService: NotificationService(spy));

    await tester.tap(find.byKey(const Key('pay-s1')));
    await tester.pumpAndSettle();

    // Amount pre-filled from the setting.
    final field = tester.widget<TextFormField>(
        find.byKey(const Key('lease_amount_field')));
    expect(field.controller!.text, formatMoney(4000));

    await tester.enterText(
        find.byKey(const Key('lease_amount_field')), '3900');
    await tester.tap(find.byKey(const Key('record_lease_payment')));
    await tester.pumpAndSettle();

    // Old due date gone from the list; advanced one present.
    expect(find.textContaining('2026-10-25'), findsNothing);
    expect(find.textContaining('2026-12-25'), findsOneWidget);

    final record = store.leaseChequeRecords.single;
    expect(record.amount, 3900);
    expect(record.dueDate, due);
    expect(store.leaseChequeSettings.single.nextDueDate,
        DateTime(2026, 12, 25));

    // Reminder rescheduled for the NEW due date only (global toggle on).
    DateTime reminderFor(DateTime d) =>
        DateTime(d.year, d.month, d.day - 3, 9);
    expect(spy.scheduled, contains(reminderFor(DateTime(2026, 12, 25))));
    expect(spy.scheduled, isNot(contains(reminderFor(due))));
  });

  testWidgets('cancels the reminder instead when the global toggle is off',
      (tester) async {
    SharedPreferences.setMockInitialValues({'notificationsEnabled': false});
    prefs = Prefs(await SharedPreferences.getInstance());
    store.upsertChequeSetting(setting(
        id: 's1', flatId: 'f1', nextDueDate: DateTime(2026, 10, 25)));

    final spy = SpyScheduler();
    await pumpScreen(tester, notificationService: NotificationService(spy));

    await tester.tap(find.byKey(const Key('pay-s1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('record_lease_payment')));
    await tester.pumpAndSettle();

    expect(spy.scheduled, isEmpty);
    final service = NotificationService(spy);
    expect(spy.cancelledIds,
        contains(service.reminderIdFor(store.leaseChequeSettings.single)));
  });
}
