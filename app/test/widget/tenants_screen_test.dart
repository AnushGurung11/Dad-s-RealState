import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
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
    store.upsertBed(const Bed(id: 'b1', flatId: 'f1', label: 'Bed A1', monthlyRent: 4000));
    store.upsertBed(const Bed(id: 'b2', flatId: 'f1', label: 'Bed A2', monthlyRent: 4500));
    store.upsertPerson(Person(id: 'p1', name: 'Alice', contact: '9000000001'));
    store.upsertPerson(Person(id: 'p2', name: 'Bob', contact: '9000000002'));
    return store;
  }

  testWidgets('add a tenant shows them in the list', (tester) async {
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
    expect(find.textContaining('No bed assigned'), findsOneWidget);
  });

  testWidgets('assign flow requires a deposit value >0 before confirming',
      (tester) async {
    await pumpApp(tester, store: seededStore());
    await tapNavTab(tester, 'Tenants');

    final aliceAssign = find.descendant(
      of: find.widgetWithText(Card, 'Alice'),
      matching: find.byIcon(Icons.link),
    );
    await tester.tap(aliceAssign);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bed A1'));
    await tester.pumpAndSettle();

    // Leave deposit empty: validation must block confirmation.
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.text('Deposit must be more than 0'), findsOneWidget);
    expect(find.text('Assign Alice'), findsOneWidget);

    // Enter a valid deposit and confirm.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Deposit'), '8000');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bed A1'), findsOneWidget);
  });

  testWidgets('assign picker only lists vacant beds and unassign works',
      (tester) async {
    final store = seededStore();
    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Tenants');

    // Assign Alice to Bed A1.
    final aliceAssign = find.descendant(
      of: find.widgetWithText(Card, 'Alice'),
      matching: find.byIcon(Icons.link),
    );
    await tester.tap(aliceAssign);
    await tester.pumpAndSettle();

    expect(find.text('Assign Alice'), findsOneWidget);
    expect(find.text('Bed A1'), findsWidgets);
    expect(find.text('Bed A2'), findsWidgets);

    await tester.tap(find.text('Bed A1'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Deposit'), '8000');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bed A1'), findsOneWidget);

    // Assigning Bob should only offer the remaining vacant bed (Bed A2).
    final bobAssign = find.descendant(
      of: find.widgetWithText(Card, 'Bob'),
      matching: find.byIcon(Icons.link),
    );
    await tester.tap(bobAssign);
    await tester.pumpAndSettle();

    expect(find.text('Assign Bob'), findsOneWidget);
    expect(find.text('Bed A2'), findsWidgets);
    expect(find.text('Bed A1'), findsNothing);

    await tester.tap(find.text('Bed A2'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Deposit'), '9000');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bed A2'), findsOneWidget);

    // Unassign Alice: the link icon becomes available again.
    final aliceUnassign = find.descendant(
      of: find.widgetWithText(Card, 'Alice'),
      matching: find.byIcon(Icons.link_off),
    );
    await tester.tap(aliceUnassign);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Unassign'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No bed assigned'), findsNWidgets(1));
    expect(store.beds.singleWhere((b) => b.id == 'b1').tenantId, isNull);
  });

  testWidgets('leaveDate auto-fills from joinDate + plannedStayMonths and is editable',
      (tester) async {
    await pumpApp(tester, store: seededStore());
    await tapNavTab(tester, 'Tenants');

    final aliceAssign = find.descendant(
      of: find.widgetWithText(Card, 'Alice'),
      matching: find.byIcon(Icons.link),
    );
    await tester.tap(aliceAssign);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bed A1'));
    await tester.pumpAndSettle();

    // Auto leave date = today + 3 (default planned stay).
    final now = DateTime.now();
    final expectedLeave = TenureService.computedLeaveDate(now, 3);
    expect(
      find.textContaining(
          'Leave date: ${expectedLeave.day}/${expectedLeave.month}/${expectedLeave.year} (auto)'),
      findsOneWidget,
    );

    // Changing planned stay recomputes the auto leave date.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Planned stay (months)'), '6');
    await tester.pumpAndSettle();
    final expectedLeave6 = TenureService.computedLeaveDate(now, 6);
    expect(
      find.textContaining(
          'Leave date: ${expectedLeave6.day}/${expectedLeave6.month}/${expectedLeave6.year} (auto)'),
      findsOneWidget,
    );
  });

  testWidgets('remaining balance shown matches tenure_service output',
      (tester) async {
    final store = seededStore();
    store.upsertPerson(Person(
      id: 'p3',
      name: 'Carol',
      contact: '9000000003',
      bedId: 'b1',
      joinDate: DateTime(2026, 1, 10),
      plannedStayMonths: 2,
      leaveDate: DateTime(2026, 3, 10),
      depositAmount: 3000,
    ));
    store.upsertBed(const Bed(id: 'b1', flatId: 'f1', label: 'Bed A1', monthlyRent: 4000, tenantId: 'p3'));

    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Tenants');

    // 4000 × 2 − 3000 = 5000
    final balance = TenureService.remainingBalance(
      store.people.singleWhere((p) => p.id == 'p3'),
      4000,
      store.payments,
    );
    expect(balance, 5000);
    expect(find.textContaining('Balance Rs. 5000'), findsOneWidget);
  });

  testWidgets('delete tenant confirms and removes them', (tester) async {
    final store = InMemoryJsonStore();
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      contact: '9000000001',
    ));

    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Tenants');

    await tester.tap(find.byTooltip('Delete tenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsNothing);
    expect(find.text('No tenants yet. Add a tenant to assign them a bed.'),
        findsOneWidget);
  });
}