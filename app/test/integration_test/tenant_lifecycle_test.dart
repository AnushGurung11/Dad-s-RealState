import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/main.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/json_store.dart';

/// End-to-end tenant lifecycle:
///   Add tenant → Assign (flat → bed → person) → appears on Tenants page →
///   Mark absconded with a note → bed frees, person moves to Archive with
///   the correct badge, and any payment record they had is still reachable
///   from their archive detail.
void main() {
  testWidgets('add, assign, abscond: full lifecycle', (tester) async {
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
        id: 'b$i',
        flatId: 'f1',
        label: 'Bed $i',
        defaultMonthlyRent: 4000,
        tenantId: null,
      ));
    }

    await tester.pumpWidget(LuckyApp(createStore: () => store));
    await tester.pumpAndSettle();

    Future<void> openDrawer() async {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
    }

    /// Opens the drawer and navigates to [item], expanding its [group]
    /// first when the section starts collapsed.
    Future<void> drawerGo(String group, String item) async {
      await openDrawer();
      Finder itemFinder() => find.descendant(
          of: find.byType(Drawer), matching: find.text(item));
      if (!tester.any(itemFinder())) {
        await tester.tap(find.descendant(
            of: find.byType(Drawer), matching: find.text(group)));
        await tester.pumpAndSettle();
      }
      await tester.tap(itemFinder());
      await tester.pumpAndSettle();
    }

    // ── 1. Add an unassigned tenant ─────────────────────────────────
    await drawerGo('Tenants', 'Add tenant');

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Zara');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact'), '9000000099');
    await tester.tap(find.byKey(const Key('save_tenant_button')));
    await tester.pumpAndSettle();

    final zaraId =
        store.people.singleWhere((p) => p.name == 'Zara').id;
    expect(store.people.singleWhere((p) => p.id == zaraId).bedId, isNull);

    // ── 2. Assign via the reordered flow: flat → bed → person ──────
    await drawerGo('Tenants', 'Assign');

    await tester.tap(find.byKey(const Key('assign_flat_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alpha').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assign_bed_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bed-dot-b2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assign_person_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zara').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Deposit (AED)'), '5000');
    await tester.ensureVisible(find.byKey(const Key('assign_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assign_submit')));
    await tester.pumpAndSettle();

    expect(store.beds.singleWhere((b) => b.id == 'b2').tenantId, zaraId);

    // ── 3. Zara shows up on the Tenants page under Alpha ────────────
    await drawerGo('Tenants', 'All tenants');

    expect(find.text('Zara'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    // Unpaid this month.
    expect(find.text('Unpaid'), findsOneWidget);

    // ── 4. Mark absconded with a note ────────────────────────────────
    await tester.tap(find.text('Zara'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mark_absconded_action')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('absconded_note_field')),
        'left owing 2 months');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_absconded')));
    await tester.pumpAndSettle();

    final zaraAfter =
        store.people.singleWhere((p) => p.id == zaraId);
    expect(zaraAfter.status, PersonStatus.absconded);
    expect(zaraAfter.statusNote, 'left owing 2 months');
    // Bed freed immediately.
    expect(store.beds.singleWhere((b) => b.id == 'b2').tenantId, isNull);

    // ── 5. Archive shows her with the red badge + note ──────────────
    await drawerGo('Settings', 'Archive');
    // The Archive section links out to the tenant archive list.
    await tester.tap(find.byKey(const Key('settings_archived_tenants')));
    await tester.pumpAndSettle();

    expect(find.text('Zara'), findsOneWidget);
    expect(find.text('Absconded'), findsOneWidget);
    expect(find.textContaining('left owing 2 months'), findsOneWidget);

    // Her detail stays reachable from the archive with history intact.
    await tester.tap(find.text('Zara'));
    await tester.pumpAndSettle();
    expect(zaraAfter.depositAmount, isNotNull); // records preserved
  });
}
