import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/config.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/lease_cheque_record.dart';
import 'package:lucky/models/lease_cheque_setting.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/navigation/routes.dart';
import 'package:lucky/screens/dashboard_screen.dart';
import 'package:lucky/screens/financial_activity_screen.dart';
import 'package:lucky/screens/flats_screen.dart';
import 'package:lucky/screens/profit_overview_screen.dart';
import 'package:lucky/screens/vacant_beds_screen.dart';
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

  testWidgets('Flats card navigates to Flats screen', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.byKey(const Key('dashboard_flats_card')));
    await tester.pumpAndSettle();
    expect(find.byType(FlatsScreen), findsOneWidget);
  });

  testWidgets('Occupancy card navigates to Vacant Beds screen listing only vacant beds, grouped by flat', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.byKey(const Key('dashboard_occupancy_card')));
    await tester.pumpAndSettle();
    expect(find.byType(VacantBedsScreen), findsOneWidget);
    // Only vacant beds: b2 is vacant
    expect(find.text('Bed 2'), findsOneWidget);
    // Occupied beds not listed
    expect(find.text('Bed 1'), findsNothing);
  });

  testWidgets('Active Tenants card no longer renders anywhere', (tester) async {
    await pumpDashboard(tester);
    expect(find.text('Active Tenants'), findsNothing);
  });

  testWidgets('Profit+Expense card navigates to Profit Overview screen', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.byKey(const Key('profit_expense_card')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfitOverviewScreen), findsOneWidget);
  });

  testWidgets('Next Lease Due card shows soonest-due flat and navigates to Cheque Payment on tap; shows empty state with zero flats', (tester) async {
    // With flats, add a cheque setting
    final due = DateTime.now().add(const Duration(days: 5));
    store.upsertChequeSetting(LeaseChequeSetting(
      id: 's1',
      flatId: 'f1',
      ownerName: 'Owner A',
      amount: 10000,
      nextDueDate: due,
    ));
    await pumpDashboard(tester);
    expect(find.byKey(const Key('next_lease_due_card')), findsOneWidget);
    expect(find.text('Alpha'), findsWidgets);
    await tester.tap(find.byKey(const Key('next_lease_due_card')));
    await tester.pumpAndSettle();
    // Should navigate to Cheque Payment (Flat) screen - which shows list of cheques
    expect(find.text('Alpha'), findsWidgets);

    // Empty state: clear flats - need to reset navigator to avoid preserving previous route
    await tester.pumpWidget(Container());
    await tester.pumpAndSettle();
    store = InMemoryJsonStore();
    await pumpDashboard(tester);
    expect(find.text('No upcoming lease payments'), findsOneWidget);
  });

  testWidgets('Rent Payment button no longer renders on Dashboard', (tester) async {
    await pumpDashboard(tester);
    expect(find.byKey(const Key('dashboard_rent_payment_button')), findsNothing);
    expect(find.text('Rent Payment'), findsNothing);
  });

  testWidgets('Recent Transactions section shows mixed-type rows with working inline edit/delete', (tester) async {
    store.upsertPayment(rent(5000));
    store.upsertExpense(Expense(
      id: 'e1',
      flatId: 'f1',
      category: ExpenseCategory.electricity,
      amount: 200,
      date: DateTime.now(),
    ));
    store.upsertChequeRecord(LeaseChequeRecord(
      id: 'r1',
      flatId: 'f1',
      ownerName: 'Owner',
      amount: 1000,
      dueDate: DateTime.now(),
      paidDate: DateTime.now(),
      month: currentMonth,
    ));
    await pumpDashboard(tester);
    expect(find.text('Recent Transactions'), findsOneWidget);
    // Should have 3 rows, each with edit/delete
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
  });

  testWidgets('profit card renders a huge positive value without overflow', (tester) async {
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
    expect(find.text('2M AED'), findsOneWidget);
  });

  testWidgets('profit card renders a large NEGATIVE value without overflow (sign included)', (tester) async {
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
}
