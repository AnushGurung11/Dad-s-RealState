import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/json_store.dart';

import '../helpers.dart';

void main() {
  testWidgets('add a tenant shows them in the list', (tester) async {
    final store = InMemoryJsonStore();
    await pumpApp(tester, store: store);
    await tapNavTab(tester, 'Tenants');

    await tester.tap(find.widgetWithText(FilledButton, 'Add tenant').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Full name'), 'Ramesh Gurung');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone'), '9841000001');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Ramesh Gurung'), findsOneWidget);
    expect(find.text('No bed assigned'), findsOneWidget);
  });

  testWidgets('assign picker only lists vacant beds', (tester) async {
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha House',
      address: '1 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertBed(const Bed(id: 'b1', flatId: 'f1', label: 'Bed A1', monthlyRent: 4000));
    store.upsertBed(const Bed(id: 'b2', flatId: 'f1', label: 'Bed A2', monthlyRent: 4500));
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      phone: '9000000001',
      moveInDate: DateTime(2026, 1, 1),
    ));
    store.upsertPerson(Person(
      id: 'p2',
      name: 'Bob',
      phone: '9000000002',
      moveInDate: DateTime(2026, 1, 1),
    ));

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

    expect(find.textContaining('Bed A1'), findsOneWidget);
    expect(find.textContaining('Alpha House'), findsWidgets);

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

    expect(find.text('No bed assigned'), findsNWidgets(1));
  });

  testWidgets('delete tenant confirms and removes them', (tester) async {
    final store = InMemoryJsonStore();
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      phone: '9000000001',
      moveInDate: DateTime(2026, 1, 1),
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
