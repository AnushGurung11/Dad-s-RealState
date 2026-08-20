import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/lease_check_setting.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/notification_service.dart';
import 'package:renttrack/widgets/summary_card.dart';

import '../helpers.dart';

void main() {
  final now = DateTime.now();
  DateTime thisMonthDue() => DateTime(now.year, now.month, now.day + 5);
  DateTime nextMonthDue() => DateTime(now.year, now.month + 1, 5);
  DateTime threeMonthsOut() => DateTime(now.year, now.month + 3, 5);

  LeaseCheckSetting check({
    required String id,
    required String flatId,
    required DateTime nextDueDate,
    String ownerName = 'Owner',
    double amount = 4000,
  }) {
    return LeaseCheckSetting(
      id: id,
      flatId: flatId,
      ownerName: ownerName,
      amount: amount,
      nextDueDate: nextDueDate,
    );
  }

  InMemoryJsonStore storeWithChecks() {
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
    store.upsertFlat(Flat(
      id: 'f3',
      name: 'Gamma House',
      address: '3 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertBed(
        const Bed(id: 'b1', flatId: 'f1', label: 'Bed A1', monthlyRent: 4000));
    store.upsertBed(const Bed(
        id: 'b2', flatId: 'f1', label: 'Bed A2', monthlyRent: 4000, tenantId: 'p1'));
    store.upsertCheckSetting(
      check(
        id: 's1',
        flatId: 'f1',
        nextDueDate: thisMonthDue(),
        ownerName: 'Owner A',
        amount: 4000,
      ),
    );
    store.upsertCheckSetting(
      check(
        id: 's2',
        flatId: 'f2',
        nextDueDate: nextMonthDue(),
        ownerName: 'Owner B',
        amount: 6000,
      ),
    );
    store.upsertCheckSetting(
      check(
        id: 's3',
        flatId: 'f3',
        nextDueDate: threeMonthsOut(),
        ownerName: 'Owner C',
        amount: 9000,
      ),
    );
    return store;
  }

  testWidgets(
      'renders summary cards and checks due this/next month under correct headers',
      (tester) async {
    await pumpApp(tester, store: storeWithChecks());

    expect(
      find.descendant(
        of: find.byType(SummaryCard),
        matching: find.text('Flats'),
      ),
      findsOneWidget,
    );
    expect(find.text('Beds occupied'), findsOneWidget);
    expect(find.text('Beds vacant'), findsOneWidget);

    // No net-profit card anywhere.
    expect(find.textContaining('Net ('), findsNothing);

    expect(find.text('Checks due this month'), findsOneWidget);
    expect(find.text('Checks due next month'), findsOneWidget);
    expect(find.text('Alpha House · Owner A'), findsOneWidget);
    expect(find.textContaining('AED 4000'), findsWidgets);
    expect(find.text('Beta House · Owner B'), findsOneWidget);
    expect(find.textContaining('AED 6000'), findsWidgets);
    expect(find.text('Gamma House · Owner C'), findsNothing);
  });

  testWidgets('a month with zero due checks shows no header/row for it',
      (tester) async {
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha House',
      address: '1 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertCheckSetting(
      check(
        id: 's1',
        flatId: 'f1',
        nextDueDate: threeMonthsOut(),
        ownerName: 'Owner A',
      ),
    );

    await pumpApp(tester, store: store);

    expect(find.text('Checks due this month'), findsNothing);
    expect(find.text('Checks due next month'), findsNothing);
    expect(find.text('No checks due in the next 2 months.'), findsOneWidget);
  });

  testWidgets('Mark Paid removes the item and updates underlying data',
      (tester) async {
    final store = storeWithChecks();
    final fake = FakeNotificationScheduler();
    await pumpApp(
      tester,
      store: store,
      notifications: NotificationService(fake),
    );

    await tester.tap(find.text('Mark paid').first);
    await tester.pumpAndSettle();

    // Item gone from the to-do list.
    expect(find.text('Alpha House · Owner A'), findsNothing);

    // CheckRecord archived with the right due month; nextDueDate advanced.
    expect(store.leaseCheckRecords, hasLength(1));
    final record = store.leaseCheckRecords.single;
    expect(record.flatId, 'f1');
    expect(record.amount, 4000);
    expect(record.ownerName, 'Owner A');
    final advanced = store.leaseCheckSettings
        .firstWhere((s) => s.id == 's1');
    expect(
      advanced.nextDueDate,
      DateTime(now.year, now.month + 2, now.day + 5),
    );

    // Notification rescheduled: old cancelled, new one scheduled.
    expect(fake.cancelled, isNotEmpty);
    expect(fake.scheduled, hasLength(1));
    expect(
      fake.scheduled.single.when,
      DateTime(now.year, now.month + 2, now.day + 5 - 3, 9),
    );
  });

  testWidgets('shows empty state with zero flats', (tester) async {
    await pumpApp(tester);

    expect(
      find.text('Add a flat to start tracking your lease checks.'),
      findsOneWidget,
    );
    expect(find.text('Go to Flats'), findsOneWidget);
  });
}