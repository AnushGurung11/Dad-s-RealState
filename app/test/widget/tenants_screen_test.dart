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
    // Unassigned people are not on the Tenants page either.
    store.upsertPerson(person(id: 'p5', name: 'Eve'));
  });

  testWidgets('shows only ACTIVE assigned tenants, grouped by flat with '
      'colored dots', (tester) async {
    await pumpTenants(tester);

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    expect(find.text('Carol'), findsNothing); // archived
    expect(find.textContaining('Absconded'), findsNothing); // Dan hidden
    expect(find.text('Eve'), findsNothing); // unassigned

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.byKey(const Key('group-dot-f1')), findsOneWidget);
    expect(find.byKey(const Key('group-dot-f2')), findsOneWidget);
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

  testWidgets('search filters by name across flats', (tester) async {
    await pumpTenants(tester);

    await tester.enterText(
        find.byKey(const Key('tenants_search_field')), 'bob');
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('Add tenant button lives ON the page and navigates',
      (tester) async {
    await pumpTenants(tester);

    await tester.tap(find.byKey(const Key('tenants_add_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_route')), findsOneWidget);
  });

  testWidgets('Assign button lives ON the page and navigates',
      (tester) async {
    await pumpTenants(tester);

    await tester.tap(find.byKey(const Key('tenants_assign_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assign_route')), findsOneWidget);
  });

  testWidgets('tapping a tenant opens their detail', (tester) async {
    await pumpTenants(tester);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail_route')), findsOneWidget);
  });
}
