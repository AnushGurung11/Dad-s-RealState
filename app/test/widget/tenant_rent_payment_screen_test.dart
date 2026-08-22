import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/config.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/screens/tenant_rent_payment_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';
import 'package:lucky/theme/flat_color.dart';
import 'package:lucky/widgets/status_badge.dart';

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
      id: 'b1',
      flatId: 'f1',
      label: 'Bed 1',
      defaultMonthlyRent: 4000,
      tenantId: 'p1');
  const bedB2 = Bed(
      id: 'b2',
      flatId: 'f1',
      label: 'Bed 2',
      defaultMonthlyRent: 4000,
      tenantId: 'p3');
  const bedB3 = Bed(
      id: 'b3',
      flatId: 'f2',
      label: 'Bed 1',
      defaultMonthlyRent: 4500,
      tenantId: 'p2');

  Person person({
    required String id,
    required String name,
    String? bedId,
    String? flatId,
    PersonStatus status = PersonStatus.active,
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
      );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: TenantRentPaymentScreen()),
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
    store.upsertBed(bedB3);
    store.upsertPerson(person(id: 'p1', name: 'Alice', bedId: 'b1', flatId: 'f1'));
    store.upsertPerson(person(id: 'p2', name: 'Bob', bedId: 'b3', flatId: 'f2'));
    // Left but still referencing her old bed — must not be payable.
    store.upsertPerson(person(
        id: 'p3', name: 'Carol', bedId: 'b2', flatId: 'f1',
        status: PersonStatus.archived));
    store.upsertPerson(person(id: 'p4', name: 'Dave')); // unassigned
  });

  testWidgets('lists active tenants grouped by flat with colored headers',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Carol'), findsNothing); // left
    expect(find.text('Dave'), findsNothing); // unassigned

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    final dotF1 =
        tester.widget<Container>(find.byKey(const Key('group-dot-f1')));
    expect((dotF1.decoration as BoxDecoration).color, flatColorFor('f1'));
    final dotF2 =
        tester.widget<Container>(find.byKey(const Key('group-dot-f2')));
    expect((dotF2.decoration as BoxDecoration).color, flatColorFor('f2'));
  });

  testWidgets('search filters tenants by name', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
        find.byKey(const Key('tenant_payment_search_field')), 'ali');
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);

    await tester.enterText(
        find.byKey(const Key('tenant_payment_search_field')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No tenants match "zzz".'), findsOneWidget);
  });

  testWidgets('each row shows the Paid badge only after a rent record for '
      'the current month exists; Unpaid otherwise', (tester) async {
    await pumpScreen(tester);

    // Nobody has paid this month yet.
    expect(find.byKey(const Key('unpaid-p1')), findsOneWidget);
    expect(find.byKey(const Key('unpaid-p2')), findsOneWidget);
    expect(find.widgetWithText(StatusBadge, 'Paid'), findsNothing);

    // Alice pays → her row flips to Paid (re-mount; the store is not
    // reactive within a mounted screen).
    final payment = Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: monthKey(DateTime.now()),
      amountDue: 4000,
      amountPaid: 4000,
      type: PaymentType.rent,
    );
    store.upsertPayment(payment);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpScreen(tester);

    expect(find.widgetWithText(StatusBadge, 'Paid'), findsOneWidget);
    expect(find.byKey(const Key('unpaid-p2')), findsOneWidget);
  });

  testWidgets('payment form starts empty and saves a single-month rent '
      'payment when Months paying stays at 1', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    // Deliberately pre-fills nothing.
    final field = tester
        .widget<TextFormField>(find.byKey(const Key('rent_amount_field')));
    expect(field.controller!.text, isEmpty);
    expect(find.byKey(const Key('months_value')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('rent_amount_field')), '2500');
    await tester.pump(); // let onChanged fire and rebuild button
    await tester.tap(find.byKey(const Key('record_rent_payment')));
    await tester.pumpAndSettle();

    final payment = store.payments.single;
    expect(payment.type, PaymentType.rent);
    expect(payment.personId, 'p2');
    expect(payment.bedId, 'b3');
    expect(payment.flatId, 'f2');
    expect(payment.amountPaid, 2500);
    expect(payment.month, monthKey(DateTime.now()));
  });

  testWidgets('"Months paying for" > 1 shows an editable per-month preview '
      'before save', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Alice')); // rent 4000
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('rent_amount_field')), '4000');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('months_plus')));
    await tester.tap(find.byKey(const Key('months_plus')));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget); // stepper value
    expect(find.text('Preview — edit each month before saving:'),
        findsOneWidget);
    // Future months default to the person's rent.
    String valueOf(Key key) => tester
        .widget<TextFormField>(find.byKey(key))
        .initialValue!;
    expect(valueOf(const Key('month_amount_1')), '4000');
    expect(valueOf(const Key('month_amount_2')), '4000');

    // Edit month 2's amount — must be honored on save.
    await tester.enterText(find.byKey(const Key('month_amount_2')), '3700');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('record_rent_payment')));
    await tester.pumpAndSettle();

    expect(store.payments, hasLength(3));
    expect(store.payments[0].amountPaid, 4000);
    expect(store.payments[1].amountPaid, 4000);
    expect(store.payments[2].amountPaid, 3700);
  });
}
