import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/lease_cheque_setting.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/navigation/routes.dart';
import 'package:renttrack/screens/settings_screen.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/notification_service.dart';
import 'package:renttrack/services/prefs.dart';
import 'package:renttrack/services/store_scope.dart';
import 'package:renttrack/theme/app_theme.dart';
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

  final flat = Flat(
    id: 'f1',
    name: 'Alpha',
    address: '1 A Road',
    createdAt: DateTime(2026, 1, 1),
  );
  const bed = Bed(id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000);

  LeaseChequeSetting setting({
    String id = 's1',
    required DateTime nextDueDate,
  }) =>
      LeaseChequeSetting(
        id: id,
        flatId: 'f1',
        ownerName: 'Owner',
        amount: 4000,
        nextDueDate: nextDueDate,
        notifyEnabled: true,
      );

  Person archivedAlice() => Person(
        id: 'p1',
        name: 'Alice',
        contact: '9000000001',
        bedId: 'b1',
        flatId: 'f1',
        joinDate: DateTime(2026, 1, 1),
        plannedStayMonths: 12,
        vacatedDate: DateTime(2026, 6, 1),
        depositAmount: 5000,
        monthlyRent: 4000,
        archived: true,
        archivedAt: DateTime(2026, 6, 2),
      );

  Future<void> pumpSettings(
    WidgetTester tester, {
    NotificationService? notificationService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: Scaffold(
          body: SettingsScreen(
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
    store.upsertFlat(flat);
    store.upsertBed(bed);
  });

  testWidgets('toggling notifications off cancels all scheduled reminders',
      (tester) async {
    final due1 = DateTime.now().add(const Duration(days: 40));
    final due2 = DateTime.now().add(const Duration(days: 70));
    store.upsertChequeSetting(setting(nextDueDate: due1));
    store.upsertChequeSetting(setting(id: 's2', nextDueDate: due2));

    final spy = SpyScheduler();
    await pumpSettings(tester, notificationService: NotificationService(spy));

    expect(find.text('Lease cheque reminders'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    final service = NotificationService(spy);
    expect(spy.cancelledIds, contains(service.reminderIdFor(store.leaseChequeSettings.first)));
    expect(spy.cancelledIds, contains(service.reminderIdFor(store.leaseChequeSettings.last)));
    expect(spy.scheduled, isEmpty);
    expect(await prefs.notificationsEnabled(), isFalse);
  });

  testWidgets('toggling back on reschedules based on current due dates, '
      'not stale ones', (tester) async {
    final staleDue = DateTime.now().add(const Duration(days: 40));
    store.upsertChequeSetting(setting(nextDueDate: staleDue));

    final spy = SpyScheduler();
    final service = NotificationService(spy);
    await pumpSettings(tester, notificationService: service);

    // Off — everything cancelled, nothing scheduled.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(spy.scheduled, isEmpty);

    // The cheque due date moves while the switch is off.
    final newDue = DateTime.now().add(const Duration(days: 90));
    store.upsertChequeSetting(setting(nextDueDate: newDue));

    // On again — reschedules from the CURRENT due date.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    DateTime reminderFor(DateTime due) =>
        DateTime(due.year, due.month, due.day - 3, 9);
    expect(spy.scheduled, contains(reminderFor(newDue)));
    expect(spy.scheduled, isNot(contains(reminderFor(staleDue))));
  });

  testWidgets('archive list shows only archived people; search filters by '
      'name', (tester) async {
    store.upsertPerson(archivedAlice());
    store.upsertPerson(const Person(
        id: 'p2', name: 'Bob', contact: '9000000002'));
    await pumpSettings(tester);

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);
    expect(find.textContaining('Archived 2026-06-02'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('archive_search_field')), 'ali');
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('archive_search_field')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matches for "zzz".'), findsOneWidget);
  });

  testWidgets('shows an empty state when nobody is archived', (tester) async {
    await pumpSettings(tester);
    expect(find.text('No archived tenants.'), findsOneWidget);
  });

  testWidgets('tapping an archived person shows their detail with Renew '
      'stay hidden and history intact', (tester) async {
    store.upsertPerson(archivedAlice());
    store.upsertPayment(const Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: '2026-03',
      amountDue: 4000,
      amountPaid: 4000,
      type: PaymentType.rent,
    ));

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        onGenerateRoute: buildRoute,
        home: const Scaffold(body: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.text('Archived tenant'), findsOneWidget);
    expect(find.text('Renew stay'), findsNothing);
    expect(find.text('2026-03'), findsOneWidget); // payment history intact
    expect(find.widgetWithText(ListTile, 'Rent'), findsOneWidget);
  });
}
