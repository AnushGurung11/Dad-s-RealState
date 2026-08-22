import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/main.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/theme/flat_color.dart';

/// End-to-end tenant flow driven through the real app shell:
/// Add member → Assign → appears in "Currently assigned" → bed shows
/// occupied on the Beds tab → Renew stay extends the vacated date.
void main() {
  testWidgets('add member, assign to a bed and renew the stay',
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
    store.upsertBed(const Bed(
        id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000));
    store.upsertBed(const Bed(
        id: 'b2', flatId: 'f1', label: 'Bed 2', defaultMonthlyRent: 4000));

    await tester.pumpWidget(LuckyApp(createStore: () => store));
    await tester.pumpAndSettle();

    Future<void> openDrawer() async {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
    }

    // ── 1. Add member ────────────────────────────────────────────────
    await openDrawer();
    await tester.tap(find.text('Tenants'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add member'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Alice');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact'), '0501234567');
    await tester.ensureVisible(find.text('Save member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save member'));
    await tester.pumpAndSettle();

    expect(store.people.single.name, 'Alice');

    // ── 2. Assign Alice to Alpha · Bed 1 ─────────────────────────────
    await openDrawer();
    // The Assign item hides inside the collapsible Tenants section, which
    // starts collapsed again now that the current route is the dashboard.
    await tester.tap(find.text('Tenants'));
    await tester.pumpAndSettle();
    await tester.tap(inDrawer(find.text('Assign')));
    await tester.pumpAndSettle();

    await tester.tap(dropdownField('Select tenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice').last);
    await tester.pumpAndSettle();

    await tester.tap(dropdownField('Select bed'));
    await tester.pumpAndSettle();
    // Grouped under Alpha with its flat color.
    expect(dotColorOf(tester, 'b1'), flatColorFor('f1'));
    await tester.tap(find.byKey(const ValueKey('bed-dot-b1')));
    await tester.pumpAndSettle();

    // Rent pre-filled from the bed default.
    expect(find.widgetWithText(TextFormField, '4000'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Deposit (AED)'), '5000');
    await tester.ensureVisible(find.text('Assign tenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign tenant'));
    await tester.pumpAndSettle();

    // ── 3. Appears in "Currently assigned" immediately ───────────────
    expect(find.text('Currently assigned'), findsOneWidget);
    expect(find.text('Alice'), findsWidgets);
    expect(store.people.single.bedId, 'b1');
    expect(store.people.single.flatId, 'f1');

    // ── 4. Bed shows occupied on the Beds tab ────────────────────────
    await openDrawer();
    await tester.tap(inDrawer(find.text('Flats')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Vacant'), findsOneWidget); // Bed 2 still free

    // ── 5. Open person detail from the occupied bed, renew stay ──────
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    final joined = store.people.single.joinDate!;
    DateTime leave(int months) =>
        DateTime(joined.year, joined.month + months, joined.day);
    String fmt(DateTime d) => '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    expect(find.text(fmt(leave(12))), findsOneWidget);

    await tester.ensureVisible(find.text('Renew stay'));
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

Finder inDrawer(Finder matching) =>
    find.descendant(of: find.byType(Drawer), matching: matching);

Finder dropdownField(String hint) =>
    find.widgetWithText(DropdownButtonFormField<String>, hint);

Color dotColorOf(WidgetTester tester, String bedId) =>
    (tester.widget<Container>(find.byKey(ValueKey('bed-dot-$bedId')))
                .decoration as BoxDecoration)
            .color!;
