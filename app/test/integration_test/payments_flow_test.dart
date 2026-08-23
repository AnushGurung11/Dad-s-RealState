import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucky/main.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/lease_cheque_setting.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/utils/format.dart';

/// End-to-end payments flow: a lease cheque payment advances the schedule and
/// refreshes the due row; a tenant rent payment lands in the ledger and the
/// balance reflects immediately on the detail page.
void main() {
  testWidgets('lease cheque advances schedule; rent payment updates balance',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final due = DateTime(now.year, now.month + 2, 15);

    String dateText(DateTime d) => '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha',
      address: '1 A Road',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertBed(const Bed(
        id: 'b1',
        flatId: 'f1',
        label: 'Bed 1',
        defaultMonthlyRent: 4000,
        tenantId: 'p1'));
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      contact: '9000000001',
      bedId: 'b1',
      flatId: 'f1',
      joinDate: DateTime(now.year, now.month - 1, now.day),
      plannedStayMonths: 12,
      vacatedDate: DateTime(now.year, now.month + 11, now.day),
      depositAmount: 5000,
      monthlyRent: 4000,
    ));
    store.upsertChequeSetting(LeaseChequeSetting(
      id: 's1',
      flatId: 'f1',
      ownerName: 'Owner A',
      amount: 12000,
      nextDueDate: due,
      notifyEnabled: true,
    ));

    await tester.pumpWidget(LuckyApp(createStore: () => store));
    await tester.pumpAndSettle();

    Future<void> openDrawer() async {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
    }

    // ── Flat Lease Payment ────────────────────────────────────────────
    await openDrawer();
    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Flat Lease Payment'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.textContaining(dateText(due)), findsOneWidget);

    await tester.tap(find.byKey(const Key('pay-s1')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('lease_amount_field')), '11500');
    await tester.tap(find.byKey(const Key('record_lease_payment')));
    await tester.pumpAndSettle();
    // Wait for the snackbar (async payment processing + setState).
    await tester.pumpAndSettle();

    final expectedNext = DateTime(due.year, due.month + 2, due.day);
    expect(store.leaseChequeRecords.single.amount, 11500);
    expect(store.leaseChequeSettings.single.nextDueDate, expectedNext);
    // Row refreshed with the advanced due date.
    expect(find.textContaining(dateText(expectedNext)), findsOneWidget);
    expect(find.textContaining(dateText(due)), findsNothing);

    // ── Tenant Rent Payment ───────────────────────────────────────────
    await openDrawer();
    // The Payments group is already expanded (current route is inside it).
    await tester.tap(find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Tenant Rent Payment'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('rent_amount_field')), '2500');
    await tester.pump(); // let onChanged fire and rebuild button
    await tester.tap(find.byKey(const Key('record_rent_payment')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle(); // wait for snackbar / async

    final rentPayment = store.payments
        .singleWhere((p) => p.type == PaymentType.rent);
    expect(rentPayment.amountPaid, 2500);
    expect(rentPayment.personId, 'p1');
    expect(rentPayment.month, monthKey(DateTime.now()));

    // ── Balance reflects immediately on the detail page ──────────────
    // The Assign page no longer lists tenants (patch 3 moved that to the
    // standalone Tenants page).
    await openDrawer();
    await tester.tap(find.text('Tenants'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(Drawer),
      matching: find.text('All tenants'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    final expectedBalance = (4000 * 12 - 5000 - 2500).toDouble();
    expect(find.text(formatMoneySigned(expectedBalance)), findsOneWidget);
  });
}
