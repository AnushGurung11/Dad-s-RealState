import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/config.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/navigation/routes.dart';
import 'package:lucky/screens/dashboard_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  late InMemoryJsonStore store;

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        onGenerateRoute: buildRoute,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const DashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

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

  const bed1 = Bed(id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000, tenantId: 'p1');
  const bed2 = Bed(id: 'b2', flatId: 'f1', label: 'Bed 2', defaultMonthlyRent: 4000);
  const bed3 = Bed(id: 'b3', flatId: 'f2', label: 'Bed 1', defaultMonthlyRent: 4500, tenantId: 'p2');

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

  final currentMonth = monthKey(DateTime.now());

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flatA);
    store.upsertFlat(flatB);
    store.upsertBed(bed1);
    store.upsertBed(bed2);
    store.upsertBed(bed3);
    store.upsertPerson(person(id: 'p1', name: 'Alice', bedId: 'b1', flatId: 'f1'));
    store.upsertPerson(person(id: 'p2', name: 'Bob', bedId: 'b3', flatId: 'f2'));
    store.upsertPerson(person(
        id: 'p3', name: 'Carol', bedId: 'b2', flatId: 'f1',
        status: PersonStatus.archived));
  });

  Payment rent(double paid) => Payment(
        id: 'pay-${paid.toString()}',
        personId: 'p1',
        bedId: 'b1',
        flatId: 'f1',
        month: currentMonth,
        amountDue: paid,
        amountPaid: paid,
        type: PaymentType.rent,
      );

  testWidgets('summary cards render values from dashboard_service and the '
      'two payment buttons navigate', (tester) async {
    // Profit: 9000 rent + deposit 5000 − expense 2000.
    store.upsertPayment(rent(9000));
    store.upsertPayment(Payment(
      id: 'dep1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: currentMonth,
      amountDue: 5000,
      amountPaid: 5000,
      type: PaymentType.deposit,
    ));
    store.upsertExpense(Expense(
      id: 'e1',
      flatId: 'f1',
      category: ExpenseCategory.electricity,
      amount: 2000,
      date: DateTime(DateTime.now().year, DateTime.now().month, 10),
    ));

    await pumpDashboard(tester);

    expect(find.text('Flats'), findsOneWidget);
    expect(find.text('Beds'), findsOneWidget);
    expect(find.text('Active Tenants'), findsOneWidget);
    expect(find.textContaining('12K'), findsOneWidget);

    // Lease Payment button → flat lease payment screen.
    await tester.tap(find.byKey(const Key('dashboard_lease_payment_button')));
    await tester.pumpAndSettle();
    expect(find.text('No flats with lease cheques yet.'), findsOneWidget);

    await pumpDashboard(tester);
    // Rent Payment button → tenant rent payment screen.
    await tester.tap(find.byKey(const Key('dashboard_rent_payment_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tenant_payment_search_field')),
        findsOneWidget);
  });

  testWidgets('profit card renders a huge positive value without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;

    store.upsertPayment(rent(999999));
    store.upsertPayment(Payment(
      id: 'dep-x',
      personId: 'p2',
      bedId: 'b3',
      flatId: 'f2',
      month: currentMonth,
      amountDue: 999999,
      amountPaid: 999999,
      type: PaymentType.rent,
    ));

    await pumpDashboard(tester);

    expect(tester.takeException(), isNull);
    // RenderFlex overflows would surface via takeException / error widgets.
    expect(find.text('2M AED'), findsOneWidget);
  });

  testWidgets('profit card renders a large NEGATIVE value without overflow '
      '(sign included)', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;

    store.upsertExpense(Expense(
      id: 'e-big',
      flatId: 'f1',
      category: ExpenseCategory.maintenance,
      amount: 1234567,
      date: DateTime(DateTime.now().year, DateTime.now().month, 5),
    ));

    await pumpDashboard(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('-1.2M AED'), findsOneWidget);
  });

  testWidgets('"Lease coming up next" section and the who-paid summary no '
      'longer exist — just cards + two buttons', (tester) async {
    await pumpDashboard(tester);

    expect(find.text('Next lease payment'), findsNothing);
    expect(find.text('Who paid this month'), findsNothing);
    expect(find.text('Unpaid'), findsNothing);
    expect(find.textContaining("who\u2019s paid"), findsNothing);
    expect(find.text('Collect rent'), findsNothing);
    expect(find.byKey(const Key('dashboard_lease_payment_button')),
        findsOneWidget);
    expect(find.byKey(const Key('dashboard_rent_payment_button')),
        findsOneWidget);
  });
}
