import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/main.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/theme/flat_color.dart';

/// End-to-end tenant flow driven through the real app shell:
/// Add tenant → Assign (flat → bed → person) → bed shows occupied on the
/// Beds tab → Renew stay extends the vacated date.
void main() {
  testWidgets('add tenant, assign to a bed and renew the stay',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha',
      address: '1 A Road',
      createdAt: DateTime(2026, 1, 1),
    ));
    for (var i = 1; i <= 5; i++) {
      store.upsertBed(Bed(
          id: 'b$i', flatId: 'f1', label: 'Bed $i',
          defaultMonthlyRent: 4000));
    }

    await tester.pumpWidget(LuckyApp(createStore: () => store));
    await tester.pumpAndSettle();

    Future<void> goToTenants() async {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Tenants')));
      await tester.pumpAndSettle();
    }

    Future<void> openTenantsFabAdd() async {
      await goToTenants();
      await tester.tap(find.byKey(const Key('tenants_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tenants_add_button')));
      await tester.pumpAndSettle();
    }

    Future<void> openTenantsFabAssign() async {
      await goToTenants();
      await tester.tap(find.byKey(const Key('tenants_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tenants_assign_button')));
      await tester.pumpAndSettle();
    }

    Future<void> goToFlats() async {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Flats')));
      await tester.pumpAndSettle();
    }

    // ── 1. Add an unassigned tenant ──────────────────────────────────
    await openTenantsFabAdd();

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Alice');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact'), '0501234567');
    await tester.ensureVisible(find.byKey(const Key('save_tenant_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_tenant_button')));
    await tester.pumpAndSettle();

    expect(store.people.single.name, 'Alice');
    expect(store.people.single.bedId, isNull);

    // ── 2. Assign Alice via the multi-step flow ─────────────────────
    await openTenantsFabAssign();

    // Step 1: flat
    await tester.tap(find.byKey(const Key('assign_flat_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha').last);
    await tester.pumpAndSettle();

    // Step 1: vacant bed
    await tester.tap(find.byKey(const Key('assign_bed_picker')));
    await tester.pumpAndSettle();
    expect(dotColorOf(tester, 'b1'), flatColorFor('f1'));
    await tester.tap(find.byKey(const ValueKey('bed-dot-b1')));
    await tester.pumpAndSettle();

    // Step 1: the unassigned person
    await tester.tap(find.byKey(const Key('assign_person_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice').last);
    await tester.pumpAndSettle();

    // Tap Next to advance to step 2
    await tester.tap(find.byKey(const Key('assign_next_button')));
    await tester.pumpAndSettle();

    // Rent pre-filled from the bed default.
    expect(find.widgetWithText(TextFormField, '4000'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Deposit (AED)'), '5000');
    await tester.ensureVisible(find.byKey(const Key('assign_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assign_submit')));
    await tester.pumpAndSettle();

    expect(store.people.single.bedId, 'b1');
    expect(store.people.single.flatId, 'f1');
    // Deposit recorded as income in the join month.
    expect(
        store.payments.single.type, PaymentType.deposit);

    // ── 3. Bed shows occupied on the Beds tab ────────────────────────
    await goToFlats();

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Vacant'), findsNWidgets(4)); // beds 2-5 still free

    // ── 4. Open person detail from the occupied bed, renew stay ──────
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    final joined = store.people.single.joinDate!;
    DateTime leave(int months) =>
        DateTime(joined.year, joined.month + months, joined.day);
    String fmt(DateTime d) => '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    expect(find.text(fmt(leave(12))), findsOneWidget);

    // Open actions popup menu
    await tester.tap(find.byKey(const Key('person_actions_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renew stay'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('renew_months_field')), '3');
    await tester.tap(find.text('Extend'));
    await tester.pumpAndSettle();

    expect(find.text(fmt(leave(15))), findsOneWidget);
    expect(store.people.single.plannedStayMonths, 15);
    expect(store.people.single.renewalHistory, hasLength(1));
  });
}

Color dotColorOf(WidgetTester tester, String id) =>
    (tester.widget<Container>(find.byKey(ValueKey('bed-dot-$id')))
                .decoration as BoxDecoration)
            .color!;
