import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/config.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/tenure_service.dart';

import '../helpers.dart';

void main() {
  InMemoryJsonStore seededStore() {
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha House',
      address: '1 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertBed(const Bed(id: 'b1', flatId: 'f1', label: 'Bed A1', defaultMonthlyRent: 4000));
    store.upsertBed(const Bed(id: 'b2', flatId: 'f1', label: 'Bed A2', defaultMonthlyRent: 4500));
    store.upsertPerson(Person(id: 'p1', name: 'Alice', contact: '9000000001'));
    store.upsertPerson(Person(id: 'p2', name: 'Bob', contact: '9000000002'));
    return store;
  }

  Person activeTenant() {
    return Person(
      id: 'p3',
      name: 'Carol',
      contact: '9000000003',
      bedId: 'b1',
      joinDate: DateTime(2026, 1, 10),
      plannedStayMonths: 2,
      vacatedDate: DateTime(2026, 3, 10),
      depositAmount: 3000,
      monthlyRent: 4000,
    );
  }

  testWidgets('add a tenant shows them in the list under No bed assigned',
      (tester) async {
    await pumpApp(tester);
    await tapNavTab(tester, 'Tenants');

    await tester.tap(find.widgetWithText(FilledButton, 'Add tenant').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'), 'Ramesh Gurung');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contact'), '9841000001');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Ramesh Gurung'), findsOneWidget);
    expect(find.text('No bed assigned'), findsWidgets);
  });

  testWidgets('active tenants grouped by flat with search filtering',
      (tester) async {
    final store = seededStore();
    store.upsertBed(const Bed(
      id: 'b1',
      flatId: 'f1',
      label: 'Bed A1',
      defaultMonthlyRent: 4000,
      tenantId: 'p3',
    ));
    store.upsertPerson(activeTenant());

    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Tenants');

    expect(find.text('Alpha House'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Carol'), findsOneWidget);
    expect(find.textContaining('Bed A1 · Joined'), findsOneWidget);

    // Search narrows the list.
    await tester.enterText(find.byType(TextField).first, 'car');
    await tester.pumpAndSettle();
    expect(find.text('Carol'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('past toggle shows tenants who left with stay duration',
      (tester) async {
    final store = seededStore();
    store.upsertPerson(Person(
      id: 'p3',
      name: 'Carol',
      contact: '9000000003',
      joinDate: DateTime(2026, 1, 10),
      plannedStayMonths: 2,
      vacatedDate: DateTime(2026, 3, 10),
    ));

    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Tenants');

    // Carol left the bed so she is only visible under Past.
    expect(find.text('Carol'), findsNothing);

    await tester.tap(find.text('Past'));
    await tester.pumpAndSettle();
    expect(find.text('Carol'), findsOneWidget);
    expect(find.textContaining('Left 10/3/2026'), findsOneWidget);
    expect(find.textContaining('Stayed 2mo'), findsOneWidget);
  });

  testWidgets('current-month payment status badge reflects Paid/Overdue',
      (tester) async {
    final store = seededStore();
    store.upsertBed(const Bed(
      id: 'b1',
      flatId: 'f1',
      label: 'Bed A1',
      defaultMonthlyRent: 4000,
      tenantId: 'p3',
    ));
    store.upsertPerson(activeTenant());
    final month = monthKey(DateTime.now());
    store.upsertPayment(Payment(
      id: 'pay1',
      personId: 'p3',
      bedId: 'b1',
      flatId: 'f1',
      month: month,
      amountDue: 4000,
      amountPaid: 4000,
    ));
    // Alice is unassigned but current-month unpaid: still shows Overdue.
    store.upsertPayment(Payment(
      id: 'pay2',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: month,
      amountDue: 4000,
      amountPaid: 0,
    ));

    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Tenants');

    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Partial'), findsNothing);
  });

  testWidgets('remaining balance shown on person detail matches tenure_service',
      (tester) async {
    final store = seededStore();
    store.upsertBed(const Bed(
      id: 'b1',
      flatId: 'f1',
      label: 'Bed A1',
      defaultMonthlyRent: 4000,
      tenantId: 'p3',
    ));
    store.upsertPerson(activeTenant());

    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Tenants');

    // 4000 × 2 - 3000 = 5000
    final balance = TenureService.remainingBalance(
      store.people.singleWhere((p) => p.id == 'p3'),
      4000,
      store.payments,
    );
    expect(balance, 5000);

    await tester.tap(find.text('Carol'));
    await tester.pumpAndSettle();
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('AED 5000'), findsOneWidget);
  });

  testWidgets('delete tenant from person detail confirms and removes them',
      (tester) async {
    final store = InMemoryJsonStore();
    store.upsertPerson(Person(id: 'p1', name: 'Alice', contact: '9000000001'));

    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Tenants');

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete tenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsNothing);
    expect(find.text('No tenants yet. Add a tenant to assign them a bed.'),
        findsOneWidget);
  });
}