import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/navigation/routes.dart';
import 'package:lucky/screens/assign_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';
import 'package:lucky/theme/flat_color.dart';

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

  const bedA1 =
      Bed(id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000);
  const bedA2 = Bed(
      id: 'b2', flatId: 'f1', label: 'Bed 2', defaultMonthlyRent: 4200,
      tenantId: 'p9');
  const bedB1 =
      Bed(id: 'b3', flatId: 'f2', label: 'Bed 1', defaultMonthlyRent: 3000);

  Future<void> pumpAssign(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        routes: {
          Routes.tenantsAdd: (context) =>
              const Scaffold(key: Key('add_tenant_route'), body: Text('Add')),
          Routes.flatDetail: (context) =>
              const Scaffold(key: Key('flat_detail_route'), body: Text('Flat detail')),
        },
        home: const Scaffold(body: AssignScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flatA);
    store.upsertFlat(flatB);
    store.upsertBed(bedA1);
    store.upsertBed(bedA2);
    store.upsertBed(bedB1);
    store.upsertPerson(const Person(
        id: 'p1', name: 'Alice', contact: '9000000001'));
    store.upsertPerson(const Person(
        id: 'p9', name: 'Occupant', contact: '9000000009', bedId: 'b2',
        flatId: 'f1'));
  });

  Finder dropdown(String key) => find.byKey(ValueKey<String>(key));

  Future<void> pickFlat(WidgetTester tester, String name) async {
    await tester.tap(dropdown('assign_flat_picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> pickBed(WidgetTester tester, String bedDotKey) async {
    await tester.tap(dropdown('assign_bed_picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey<String>(bedDotKey)));
    await tester.pumpAndSettle();
  }

  Future<void> pickPerson(WidgetTester tester, String name) async {
    await tester.tap(dropdown('assign_person_picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Step 1 only lists flats that still have at least one vacant '
      'bed', (tester) async {
    store.upsertBed(const Bed(
        id: 'b4', flatId: 'f2', label: 'Bed 2', defaultMonthlyRent: 3000));
    store.upsertPerson(const Person(
        id: 'p8', name: 'Fuller', contact: '9000000008', bedId: 'b3',
        flatId: 'f2'));
    store.upsertPerson(const Person(
        id: 'p7', name: 'Second', contact: '9000000007', bedId: 'b4',
        flatId: 'f2'));
    store.upsertBed(bedB1.copyWith(tenantId: 'p8'));
    store.upsertBed(const Bed(
        id: 'b4',
        flatId: 'f2',
        label: 'Bed 2',
        defaultMonthlyRent: 3000,
        tenantId: 'p7'));

    await pumpAssign(tester);

    await tester.tap(dropdown('assign_flat_picker'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
  });

  testWidgets('Step 2 lists only the chosen flat\u0027s vacant beds, colored '
      'by that flat', (tester) async {
    await pumpAssign(tester);

    await pickFlat(tester, 'Alpha');
    await tester.tap(dropdown('assign_bed_picker'));
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsNothing);
    expect(find.byKey(const ValueKey('bed-dot-b2')), findsNothing);
    expect(find.byKey(const ValueKey('bed-dot-b3')), findsNothing);

    Color dotColor(String bedId) =>
        (tester.widget<Container>(find.byKey(ValueKey('bed-dot-$bedId')))
                    .decoration as BoxDecoration)
                .color!;
    expect(dotColor('b1'), flatColorFor('f1'));
  });

  testWidgets('Step 3 only lists unassigned people; a shortcut to Add tenant '
      'exists when nobody is waiting', (tester) async {
    store.upsertBed(bedA1.copyWith(tenantId: 'p9'));
    store.deletePerson('p1');
    store.upsertPerson(const Person(
        id: 'p1x', name: 'Zed', contact: '9000000001', bedId: 'b1',
        flatId: 'f1'));

    await pumpAssign(tester);

    expect(find.byKey(const Key('assign_add_tenant_link')), findsOneWidget);
    expect(find.textContaining('add a tenant first'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assign_add_tenant_link')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_tenant_route')), findsOneWidget);
  });

  testWidgets('Next button advances to step 2, Back returns to step 1',
      (tester) async {
    await pumpAssign(tester);

    await pickFlat(tester, 'Alpha');
    await pickBed(tester, 'bed-dot-b1');
    await pickPerson(tester, 'Alice');

    // Tap Next to go to step 2
    await tester.tap(find.byKey(const Key('assign_next_button')));
    await tester.pumpAndSettle();

    // Step 2 shows tenure fields
    expect(find.text('Tenure & rent'), findsOneWidget);
    expect(find.byKey(const Key('assign_back_button')), findsOneWidget);
    expect(find.byKey(const Key('assign_submit')), findsOneWidget);

    // Tap Back to go back to step 1
    await tester.tap(find.byKey(const Key('assign_back_button')));
    await tester.pumpAndSettle();

    // Step 1 fields are visible again
    expect(find.byKey(const Key('assign_flat_picker')), findsOneWidget);
    expect(find.byKey(const Key('assign_next_button')), findsOneWidget);
  });

  testWidgets('full flow assigns the tenant and redirects to flat detail',
      (tester) async {
    await pumpAssign(tester);

    await pickFlat(tester, 'Alpha');
    await pickBed(tester, 'bed-dot-b1');
    await pickPerson(tester, 'Alice');

    // Go to step 2
    await tester.tap(find.byKey(const Key('assign_next_button')));
    await tester.pumpAndSettle();

    // Fill deposit
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Deposit (AED)'), '5000');
    await tester.ensureVisible(find.byKey(const Key('assign_submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assign_submit')));
    await tester.pumpAndSettle();

    expect(store.people.singleWhere((p) => p.id == 'p1').bedId, 'b1');
    expect(store.beds.singleWhere((b) => b.id == 'b1').tenantId, 'p1');
    expect(store.payments.single.type, PaymentType.deposit);
  });
}
