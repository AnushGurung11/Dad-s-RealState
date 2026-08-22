import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/config.dart';
import 'package:lucky/main.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/json_store.dart';

/// End-to-end multi-month payment + early termination:
///   Pay 3 months upfront → terminate mid-way through month 2 → the refund
///   includes the unused portion of month 2 PLUS all of month 3; the bed is
///   freed and the person sits in Archive showing the termination reason.
void main() {
  testWidgets('3 months upfront, terminated mid-month-2: refund = rest of '
      'month + full future months', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha',
      address: '1 A Road',
      createdAt: DateTime(2026, 1, 1),
    ));
    for (var i = 1; i <= 5; i++) {
      store.upsertBed(Bed(
        id: 'b$i',
        flatId: 'f1',
        label: 'Bed $i',
        defaultMonthlyRent: 4000,
        tenantId: null,
      ));
    }
    // Nina joined at the START of this month, staying 12 months.
    final joinDate = DateTime(now.year, now.month, 1);
    const rent = 4000.0;
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Nina',
      contact: '9000000014',
      bedId: 'b3',
      flatId: 'f1',
      joinDate: joinDate,
      plannedStayMonths: 12,
      vacatedDate: DateTime(now.year, now.month + 12, 1),
      depositAmount: 5000,
      monthlyRent: rent,
    ));
    store.upsertBed(const Bed(
        id: 'b3', flatId: 'f1', label: 'Bed 3', defaultMonthlyRent: 4000,
        tenantId: 'p1'));

    await tester.pumpWidget(LuckyApp(createStore: () => store));
    await tester.pumpAndSettle();

    Future<void> openDrawer() async {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
    }

    // ── 1. Pay 3 months upfront via Tenant Rent Payment ─────────────
    await openDrawer();
    await tester.tap(find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Tenant Rent Payment'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nina'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('rent_amount_field')), '4000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('months_plus')));
    await tester.tap(find.byKey(const Key('months_plus')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('record_rent_payment')));
    await tester.pumpAndSettle();

    // Three rent records: this month on the paid date, next two on their
    // 1sts — all in one atomic save.
    expect(store.payments.where((p) => p.type == PaymentType.rent), hasLength(3));
    expect(
      store.payments.map((p) => p.month).toSet(),
      containsAll([
        monthKey(DateTime(now.year, now.month)),
        monthKey(DateTime(now.year, now.month + 1)),
        monthKey(DateTime(now.year, now.month + 2)),
      ]),
    );

    // ── 2. Terminate mid-way through "month 2" (i.e. day ~15) ───────
    await openDrawer();
    await tester.tap(find.descendant(
      of: find.byType(Drawer),
      matching: find.text('All tenants'),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nina'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('end_tenure_action')));
    await tester.pumpAndSettle();

    // Reason: workplace change (no note needed).
    await tester.tap(find.byKey(const Key('termination_reason_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workplace change').last);
    await tester.pumpAndSettle();

    // Confirm.
    await tester.tap(find.byKey(const Key('termination_ack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_termination')));
    await tester.pumpAndSettle();

    // ── 3. Verify refund math from persisted records ─────────────────
    final terminationDay = DateTime.now().day;
    final daysInMonth =
        DateTime(now.year, now.month + 1).difference(DateTime(now.year, now.month)).inDays;
    final earnedFinalMonth = terminationDay / daysInMonth * rent;
    final expectedRefund =
        (rent - earnedFinalMonth) + rent /* full month 3 */;

    final record = store.terminations.single;
    expect(record.refundAmount, closeTo(expectedRefund, 0.01));
    expect(record.reason.name, 'workplaceChange');

    // Person archived with today as vacated date; bed freed.
    final nina = store.people.singleWhere((p) => p.id == 'p1');
    expect(nina.status, PersonStatus.archived);
    expect(store.beds.singleWhere((b) => b.id == 'b3').tenantId, isNull);

    // Payment records untouched by termination.
    expect(store.payments.where((p) => p.type == PaymentType.rent),
        hasLength(3));

    // ── 4. Archive shows Nina with the neutral "Left" badge ─────────
    await openDrawer();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings_archived_tenants')));
    await tester.pumpAndSettle();

    expect(find.text('Nina'), findsOneWidget);
    expect(find.text('Left'), findsOneWidget);
    expect(find.text('Absconded'), findsNothing);
  });
}
