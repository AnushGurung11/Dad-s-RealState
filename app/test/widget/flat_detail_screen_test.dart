import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/lease_cheque_record.dart';
import 'package:renttrack/models/lease_cheque_setting.dart';
import 'package:renttrack/services/json_store.dart';

import '../helpers.dart';

void main() {
  InMemoryJsonStore storeWithFlat({int bedCount = 1}) {
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha House',
      address: '1 Main St',
      createdAt: DateTime(2026, 1, 1),
      contractDate: DateTime(2026, 1, 5),
      contractPerson: 'Govt Housing',
      yearlyRent: 24000,
    ));
    for (var i = 1; i <= bedCount; i++) {
      store.upsertBed(Bed(
        id: 'b$i',
        flatId: 'f1',
        label: 'Bed $i',
        defaultMonthlyRent: 4000,
      ));
    }
    return store;
  }

  Future<void> openFlatDetail(
    WidgetTester tester, {
    InMemoryJsonStore? store,
  }) async {
    await pumpApp(tester, store: store ?? storeWithFlat());
    await tapNavTab(tester, 'Flats');
    await tester.tap(find.text('Alpha House'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders Beds and Lease info tabs with Beds selected by default',
      (tester) async {
    await openFlatDetail(tester);

    expect(find.text('Beds'), findsOneWidget);
    expect(find.text('Lease info'), findsOneWidget);
    // Beds content is shown by default; Lease info is not.
    expect(find.text('Bed 1'), findsOneWidget);
    expect(find.text('Lease agreement'), findsNothing);
  });

  testWidgets(
      'Lease info tab shows contract details, yearly rent, cheque and payment '
      'history', (tester) async {
    final store = storeWithFlat();
    store.upsertChequeSetting(LeaseChequeSetting(
      id: 's1',
      flatId: 'f1',
      ownerName: 'Govt Housing',
      amount: 4000,
      nextDueDate: DateTime(2026, 3, 1),
    ));
    store.upsertChequeRecord(LeaseChequeRecord(
      id: 'r1',
      flatId: 'f1',
      ownerName: 'Govt Housing',
      amount: 4000,
      dueDate: DateTime(2026, 1, 1),
      paidDate: DateTime(2026, 1, 2),
      month: '2026-01',
    ));

    await openFlatDetail(tester, store: store);
    await tester.tap(find.text('Lease info'));
    await tester.pumpAndSettle();

    expect(find.text('Lease agreement'), findsOneWidget);
    expect(find.text('1 Main St'), findsOneWidget);
    expect(find.text('5/1/2026'), findsOneWidget); // contract date
    expect(find.text('Govt Housing'), findsOneWidget); // contract person
    expect(find.text('AED 24000'), findsOneWidget); // yearly rent
    expect(find.text('Current cheque'), findsOneWidget);
    // Cheque amount appears on the current-cheque card and the history entry.
    expect(find.text('AED 4000'), findsNWidgets(2));
    expect(find.text('Cheque history'), findsOneWidget);
    expect(find.textContaining('paid 2/1/2026'), findsOneWidget);
  });

  testWidgets('switching tabs preserves the beds scroll position',
      (tester) async {
    await openFlatDetail(tester, store: storeWithFlat(bedCount: 20));

    // Scroll the beds list down to the last bed.
    await tester.dragUntilVisible(
      find.text('Bed 20'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bed 20'), findsOneWidget);
    expect(find.text('Bed 1'), findsNothing); // scrolled far past it

    // Switch to Lease info and back — the list must not reset to the top.
    await tester.tap(find.text('Lease info'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beds'));
    await tester.pumpAndSettle();

    expect(find.text('Bed 20'), findsOneWidget);
    expect(find.text('Bed 1'), findsNothing);
  });
}