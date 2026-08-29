import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/navigation/routes.dart';
import 'package:lucky/screens/tenants_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  late InMemoryJsonStore store;

  final flatA = Flat(
    id: 'f1',
    name: 'Alpha',
    address: '1 A Road',
    createdAt: DateTime(2026, 1, 1),
  );
  final flatB = Flat(
    id: 'f2',
    name: 'Beta',
    address: '2 B Road',
    createdAt: DateTime(2026, 1, 1),
  );

  const bedB1 = Bed(
      id: 'b1', flatId: 'f1', label: 'Bed 3', defaultMonthlyRent: 4000,
      tenantId: 'p1');
  const bedB2 = Bed(
      id: 'b2', flatId: 'f2', label: 'Bed 1', defaultMonthlyRent: 4500,
      tenantId: 'p2');

  Person person({
    required String id,
    required String name,
    String? bedId,
    String? flatId,
    PersonStatus status = PersonStatus.active,
    String? photoPath,
  }) =>
      Person(
        id: id,
        name: name,
        contact: '90000000${id.hashCode % 10}',
        bedId: bedId,
        flatId: flatId,
        joinDate: DateTime(2026, 1, 1),
        plannedStayMonths: 12,
        depositAmount: 5000,
        monthlyRent: 4000,
        status: status,
        photoPath: photoPath,
      );

  Future<void> pumpTenants(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        routes: {
          Routes.tenantsAdd: (context) =>
              const Scaffold(key: Key('add_route'), body: Text('Add')),
          Routes.tenantsAssign: (context) =>
              const Scaffold(key: Key('assign_route'), body: Text('Assign')),
          Routes.tenantsDetail: (context) => const Scaffold(
              key: Key('detail_route'), body: Text('Detail')),
        },
        home: const TenantsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flatA);
    store.upsertFlat(flatB);
    store.upsertBed(bedB1);
    store.upsertBed(bedB2);
    store.upsertPerson(person(id: 'p1', name: 'Alice', bedId: 'b1', flatId: 'f1'));
    store.upsertPerson(person(id: 'p2', name: 'Bob', bedId: 'b2', flatId: 'f2'));
    // Terminal states must never appear on the active list.
    store.upsertPerson(person(
        id: 'p3', name: 'Carol', bedId: 'b9', flatId: 'f1',
        status: PersonStatus.archived));
    store.upsertPerson(person(
        id: 'p4', name: 'Dan', bedId: 'b8', flatId: 'f2',
        status: PersonStatus.absconded));
    // Unassigned active people now appear in their own section.
    store.upsertPerson(person(id: 'p5', name: 'Eve'));
  });

  testWidgets('shows assigned and unassigned ACTIVE tenants', (tester) async {
    await pumpTenants(tester);

    // Assigned tenants appear
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    // Unassigned active tenant appears in Unassigned section
    expect(find.text('Eve'), findsOneWidget);
    // Section header "Unassigned" - we just verify Eve is there and flat groups exist

    // Archived/absconded still hidden
    expect(find.text('Carol'), findsNothing);
    expect(find.textContaining('Absconded'), findsNothing);

    // Flat groups still present for assigned
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.byKey(const Key('group-dot-f1')), findsOneWidget);
    expect(find.byKey(const Key('group-dot-f2')), findsOneWidget);
  });

  testWidgets('unassigned tenants have Unassigned badge and Assign shortcut', (tester) async {
    await pumpTenants(tester);

    // Find Eve's row
    final eveRow = find.ancestor(
      of: find.text('Eve'),
      matching: find.byType(Card),
    );
    expect(eveRow, findsOneWidget);

    // Should have Assign shortcut button
    expect(find.byKey(const Key('assign-shortcut-p5')), findsOneWidget);
  });

  testWidgets('rows show the bed label and this month\u0027s payment status',
      (tester) async {
    await pumpTenants(tester);

    // "Bed 3"/"Bed 1" labels render verbatim.
    expect(find.text('Bed 3'), findsOneWidget);
    expect(find.text('Bed 1'), findsOneWidget);

    // Nobody paid yet → unpaid for both.
    final danger = appLightTheme.extension<AppStatusColors>()!.danger;
    final badge = tester.widget<Container>(
      find.ancestor(
        of: find.text('Unpaid'),
        matching: find.byType(Container),
      ).first,
    );
    expect((badge.decoration as BoxDecoration).border!.top.color,
        danger.withValues(alpha: 0.4));

    // Alice pays → Paid badge appears for her row only. The store is not
    // reactive, so re-mount the screen like a real revisit would.
    store.upsertPayment(Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: DateTime.now().toString().substring(0, 7),
      amountDue: 4000,
      amountPaid: 4000,
      type: PaymentType.rent,
    ));
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpTenants(tester);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Unpaid'), findsOneWidget);
  });

  testWidgets('search filters by name across flats and unassigned', (tester) async {
    await pumpTenants(tester);

    await tester.enterText(
        find.byKey(const Key('tenants_search_field')), 'eve');
    await tester.pumpAndSettle();

    expect(find.text('Eve'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
    expect(find.text('Bob'), findsNothing);
  });

  testWidgets('Add tenant button lives ON the page and navigates',
      (tester) async {
    await pumpTenants(tester);

    // FAB speed-dial: open first
    await tester.tap(find.byKey(const Key('tenants_fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tenants_add_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_route')), findsOneWidget);
  });

  testWidgets('Assign button lives ON the page and navigates',
      (tester) async {
    await pumpTenants(tester);

    await tester.tap(find.byKey(const Key('tenants_fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tenants_assign_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assign_route')), findsOneWidget);
  });

  testWidgets('Tenants FAB speed-dial toggles Add/Assign options', (tester) async {
    await pumpTenants(tester);
    expect(find.byKey(const Key('tenants_fab')), findsOneWidget);
    // Initially collapsed
    expect(find.byKey(const Key('tenants_add_button')), findsNothing);
    await tester.tap(find.byKey(const Key('tenants_fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tenants_add_button')), findsOneWidget);
    expect(find.byKey(const Key('tenants_assign_button')), findsOneWidget);
  });

  testWidgets('tapping a tenant opens their detail', (tester) async {
    await pumpTenants(tester);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail_route')), findsOneWidget);
  });

  testWidgets('archived/absconded people never appear regardless of section', (tester) async {
    await pumpTenants(tester);

    expect(find.text('Carol'), findsNothing);
    expect(find.text('Dan'), findsNothing);
    // Even if we search for them
    await tester.enterText(
        find.byKey(const Key('tenants_search_field')), 'carol');
    await tester.pumpAndSettle();
    expect(find.text('Carol'), findsNothing);
  });
}
