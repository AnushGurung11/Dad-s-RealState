import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/json_store.dart';

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
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      phone: '9000000001',
      bedId: 'b1',
      moveInDate: DateTime(2026, 1, 1),
    ));
    return store;
  }

  testWidgets('filters by month', (tester) async {
    final store = seededStore();
    store.upsertPayment(const Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: '2026-06',
      amountDue: 4000,
      amountPaid: 4000,
    ));
    store.upsertPayment(const Payment(
      id: 'pay2',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: '2026-07',
      amountDue: 4000,
      amountPaid: 0,
    ));

    await pumpApp(
      tester,
      store: store,
      prefs: {'currentMonth': '2026-06'},
    );
    await tapNavTab(tester, 'Payments');

    expect(find.text('Alice'), findsOneWidget);

    // Jump to July and the other record appears.
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('filters by status', (tester) async {
    final store = seededStore();
    store.upsertPayment(const Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: '2026-06',
      amountDue: 4000,
      amountPaid: 4000,
    ));

    await pumpApp(tester, store: store, prefs: {'currentMonth': '2026-06'});
    await tapNavTab(tester, 'Payments');

    expect(find.text('Alice'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Unpaid'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsNothing);
    expect(find.text('No unpaid payments for 2026-06.'),
        findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Paid'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('marking a record paid updates its badge immediately',
      (tester) async {
    final store = seededStore();
    store.upsertPayment(const Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: '2026-06',
      amountDue: 4000,
      amountPaid: 1500,
    ));

    await pumpApp(tester, store: store, prefs: {'currentMonth': '2026-06'});
    await tapNavTab(tester, 'Payments');

    expect(find.text('PARTIAL'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.adaptive.more));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark paid'));
    await tester.pumpAndSettle();

    expect(find.text('PAID'), findsOneWidget);
    expect(find.text('PARTIAL'), findsNothing);
    expect(find.textContaining('Paid Rs. 4000 of Rs. 4000'), findsOneWidget);
  });

  testWidgets('adds a new payment record', (tester) async {
    final store = seededStore();

    await pumpApp(tester, store: store, prefs: {'currentMonth': '2026-06'});
    await tapNavTab(tester, 'Payments');

    expect(find.text('No payments recorded for 2026-06. Add your first payment.'),
        findsOneWidget);

await tester.tap(find.widgetWithText(FilledButton, 'Add payment').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<Person>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add').last);
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('UNPAID'), findsOneWidget);
    expect(find.textContaining('Paid Rs. 0 of Rs. 4000'), findsOneWidget);
  });
}
