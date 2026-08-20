import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/json_store.dart';

import '../helpers.dart';

void main() {
  InMemoryJsonStore storeWithBeds() {
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha House',
      address: '1 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertBed(const Bed(
      id: 'b1',
      flatId: 'f1',
      label: 'Bed A1',
      defaultMonthlyRent: 4000,
      tenantId: 'p1',
    ));
    store.upsertBed(
        const Bed(id: 'b2', flatId: 'f1', label: 'Bed A2', defaultMonthlyRent: 4500));
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      contact: '9000000001',
      bedId: 'b1',
      joinDate: DateTime(2026, 1, 10),
      plannedStayMonths: 3,
      monthlyRent: 3800,
      depositAmount: 5000,
      others: 'Prefers ground floor',
    ));
    return store;
  }

  Future<void> openBedsTab(
    WidgetTester tester, {
    InMemoryJsonStore? store,
  }) async {
    await pumpApp(tester, store: store ?? storeWithBeds());
    await tapNavTab(tester, 'Flats');
    await tester.tap(find.text('Alpha House'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'occupied bed row shows the tenant name and their actual rent, with no '
      'ledger detail inline', (tester) async {
    await openBedsTab(tester);

    expect(find.text('Bed A1'), findsOneWidget);
    // Uses the tenant's own monthlyRent (3800), not the bed default (4000).
    expect(find.text('Alice · AED 3800/month'), findsOneWidget);
    expect(find.text('AED 4000/month'), findsNothing);
    // No ledger/tenure detail on the brief row.
    expect(find.textContaining('Balance'), findsNothing);
    expect(find.textContaining('Deposit'), findsNothing);
  });

  testWidgets('vacant bed row shows Vacant and leaks no other bed data',
      (tester) async {
    await openBedsTab(tester);

    expect(find.text('Vacant'), findsOneWidget);
    // Only the occupied row carries rent; the vacant row must not show the
    // other bed's tenant or the vacant bed's default rent.
    expect(find.textContaining('/month'), findsOneWidget);
    expect(find.textContaining('Alice'), findsOneWidget);
  });

  testWidgets('tapping a vacant bed opens the Assign tenant form',
      (tester) async {
    await openBedsTab(tester);

    await tester.tap(find.text('Bed A2'));
    await tester.pumpAndSettle();

    expect(find.text('Assign Bed A2'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
  });

  testWidgets('tapping an occupied bed opens that person detail screen',
      (tester) async {
    await openBedsTab(tester);

    await tester.tap(find.text('Bed A1'));
    await tester.pumpAndSettle();

    // The person detail shows the captured monthlyRent, deposit and notes.
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('AED 3800'), findsOneWidget);
    expect(find.text('AED 5000'), findsOneWidget);
    expect(find.text('Prefers ground floor'), findsOneWidget);
  });
}