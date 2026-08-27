import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/config.dart';
import 'package:lucky/main.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/tenure_service.dart';

/// End-to-end auto-archive flow: a tenant whose vacatedDate passed without a
/// renewal is archived at boot — their bed shows vacant again, they vanish
/// from the active Tenants page, they surface in Settings → Archived Tenants
/// (searchable), and their payment history stays intact.
void main() {
  testWidgets('lapsed tenant is auto-archived on launch', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    // Alice joined 13 months ago for a 12-month stay → lapsed ~1 month ago.
    final aliceJoin = DateTime(now.year, now.month - 13, now.day);
    final aliceVacated = TenureService.computedLeaveDate(aliceJoin, 12);
    expect(aliceVacated.isBefore(now), isTrue,
        reason: 'fixture must represent an already-lapsed stay');

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
    store.upsertBed(const Bed(
        id: 'b2',
        flatId: 'f1',
        label: 'Bed 2',
        defaultMonthlyRent: 4000,
        tenantId: 'p2'));
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      contact: '9000000001',
      bedId: 'b1',
      flatId: 'f1',
      joinDate: aliceJoin,
      plannedStayMonths: 12,
      vacatedDate: aliceVacated,
      depositAmount: 5000,
      monthlyRent: 4000,
    ));
    // Bob is mid-stay — the control tenant.
    store.upsertPerson(Person(
      id: 'p2',
      name: 'Bob',
      contact: '9000000002',
      bedId: 'b2',
      flatId: 'f1',
      joinDate: DateTime(now.year, now.month - 1, now.day),
      plannedStayMonths: 12,
      vacatedDate: DateTime(now.year, now.month + 11, now.day),
    ));
    store.upsertPayment(Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: monthKey(aliceJoin),
      amountDue: 4000,
      amountPaid: 4000,
    ));

    await tester.pumpWidget(LuckyApp(createStore: () => store));
    await tester.pumpAndSettle();

    // The boot sweep archived Alice and freed her bed.
    final aliceAfter = store.people.singleWhere((p) => p.id == 'p1');
    expect(aliceAfter.status, PersonStatus.archived);
    expect(aliceAfter.statusDate, isNotNull);
    expect(store.beds.singleWhere((b) => b.id == 'b1').tenantId, isNull);
    expect(store.beds.singleWhere((b) => b.id == 'b2').tenantId, 'p2');

    Future<void> openDrawer() async {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
    }

    // ── Beds tab: Bed 1 vacant again, Bob still occupied ─────────────
    await openDrawer();
    await tester.tap(find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Flats'),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Vacant'), findsOneWidget); // exactly one bed free now

    // ── Tenants page: only ACTIVE tenants are listed ────────────────
    await openDrawer();
    await tester.tap(find.text('Tenants'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(Drawer),
      matching: find.text('All tenants'),
    ));
    await tester.pumpAndSettle();

    // Alice (archived at boot) is gone; Bob is still active.
    expect(find.byKey(const Key('tenants_search_field')), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);

    // ── Archive: Alice listed and searchable ─────────────────────────
    await openDrawer();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Settings → "Archived Tenants" opens the tenant archive list.
    await tester.tap(find.byKey(const Key('settings_archived_tenants')));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);

    await tester.enterText(find.byKey(const Key('archive_search_field')), 'ali');
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);

    // ── Detail from Archive: read-only, history intact ───────────────
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.text('Left'), findsWidgets);
    expect(find.text('Renew stay'), findsNothing);
    expect(find.text(monthKey(aliceJoin)), findsOneWidget);
    expect(find.textContaining('AED 4000'), findsWidgets);
  });
}
