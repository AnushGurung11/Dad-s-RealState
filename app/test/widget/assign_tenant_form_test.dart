import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/tenure_service.dart';

import '../helpers.dart';

void main() {
  InMemoryJsonStore storeWithFlat() {
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha House',
      address: '1 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertBed(
        const Bed(id: 'b1', flatId: 'f1', label: 'Bed A1', defaultMonthlyRent: 4000));
    store.upsertBed(
        const Bed(id: 'b2', flatId: 'f1', label: 'Bed A2', defaultMonthlyRent: 4500));
    return store;
  }

  Future<void> openAssignForm(WidgetTester tester, String bedLabel) async {
    await tapNavTab(tester, 'Flats');
    await tester.tap(find.text('Alpha House'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(bedLabel));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a vacant bed opens a single-step assign form',
      (tester) async {
    await pumpApp(tester, store: storeWithFlat());
    await openAssignForm(tester, 'Bed A1');

    expect(find.text('Assign Bed A1'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Contact'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Monthly rent'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Deposit'), findsOneWidget);
  });

  testWidgets('monthly rent is pre-filled from the bed default rent',
      (tester) async {
    await pumpApp(tester, store: storeWithFlat());
    await openAssignForm(tester, 'Bed A2');

    expect(find.widgetWithText(TextFormField, 'Monthly rent'), findsOneWidget);
    expect(find.text('4500'), findsOneWidget);
  });

  testWidgets('one Save assigns the tenant and records deposit income',
      (tester) async {
    final store = storeWithFlat();
    await pumpApp(tester, store: store);
    await openAssignForm(tester, 'Bed A1');

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'), 'Ramesh Gurung');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact'), '9841000001');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Deposit'), '8000');
    await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
    await tester.pumpAndSettle();

    // Bed is occupied, tenant has tenure fields and a deposit payment.
    final bed = store.beds.singleWhere((b) => b.id == 'b1');
    expect(bed.tenantId, isNotNull);

    final person =
        store.people.singleWhere((p) => p.id == bed.tenantId);
    expect(person.name, 'Ramesh Gurung');
    expect(person.bedId, 'b1');
    expect(person.monthlyRent, 4000);
    expect(person.depositAmount, 8000);
    final now = DateTime.now();
    expect(
      person.vacatedDate,
      TenureService.computedLeaveDate(now, 3),
    );

    final deposit = store.payments.singleWhere((p) => p.personId == person.id);
    expect(deposit.type, PaymentType.deposit);
    expect(deposit.amountDue, 8000);

    // The row now shows the occupant instead of Vacant (only Bed A2 is left).
    expect(find.text('Vacant'), findsOneWidget);
    expect(find.textContaining('Ramesh Gurung'), findsOneWidget);
  });

  testWidgets('deposit must be more than 0 to confirm', (tester) async {
    await pumpApp(tester, store: storeWithFlat());
    await openAssignForm(tester, 'Bed A1');

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name'), 'Ramesh Gurung');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact'), '9841000001');
    await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
    await tester.pumpAndSettle();

    expect(find.text('Deposit must be more than 0'), findsOneWidget);
    expect(find.text('Assign Bed A1'), findsOneWidget);
  });

  testWidgets('tapping an occupied bed opens the person history instead',
      (tester) async {
    final store = storeWithFlat();
    store.upsertBed(const Bed(
      id: 'b1',
      flatId: 'f1',
      label: 'Bed A1',
      defaultMonthlyRent: 4000,
      tenantId: 'p1',
    ));
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      contact: '9000000001',
      bedId: 'b1',
      joinDate: DateTime(2026, 1, 10),
      plannedStayMonths: 3,
    ));

    await pumpApp(tester, store: store);
    await openAssignForm(tester, 'Bed A1');

    expect(find.text('Assign Bed A1'), findsNothing);
    expect(find.text('Alice'), findsWidgets);
  });
}