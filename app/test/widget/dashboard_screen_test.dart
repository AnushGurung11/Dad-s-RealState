import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/config.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/expense.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/lease_cheque_setting.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/navigation/routes.dart';
import 'package:renttrack/screens/dashboard_screen.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/store_scope.dart';
import 'package:renttrack/theme/app_theme.dart';

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
  const bed2 = Bed(id: 'b2', flatId: 'f1', label: 'Bed 2', defaultMonthlyRent: 4000, tenantId: null);
  const bed3 = Bed(id: 'b3', flatId: 'f2', label: 'Bed 1', defaultMonthlyRent: 4500, tenantId: 'p2');

  Person person({
    required String id,
    required String name,
    String? bedId,
    String? flatId,
    bool archived = false,
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
        archived: archived,
      );

  // Use current month for test fixtures to match DashboardScreen's monthKey(DateTime.now())
  final currentMonth = monthKey(DateTime.now());

  final paymentCurrRent = Payment(
    id: 'pay1',
    personId: 'p1',
    bedId: 'b1',
    flatId: 'f1',
    month: currentMonth,
    amountDue: 4000,
    amountPaid: 4000,
    type: PaymentType.rent,
  );
  final paymentCurrDeposit = Payment(
    id: 'pay2',
    personId: 'p1',
    bedId: 'b1',
    flatId: 'f1',
    month: currentMonth,
    amountDue: 5000,
    amountPaid: 5000,
    type: PaymentType.deposit,
  );

  final expenseCurr = Expense(
    id: 'e1',
    flatId: 'f1',
    category: ExpenseCategory.electricity,
    amount: 2000,
    date: DateTime(DateTime.now().year, DateTime.now().month, 10),
  );

  final setting1 = LeaseChequeSetting(
    id: 's1',
    flatId: 'f1',
    ownerName: 'Owner A',
    amount: 12000,
    nextDueDate: DateTime(DateTime.now().year, DateTime.now().month + 1, 15),
    notifyEnabled: true,
  );
  final setting2 = LeaseChequeSetting(
    id: 's2',
    flatId: 'f2',
    ownerName: 'Owner B',
    amount: 15000,
    nextDueDate: DateTime(DateTime.now().year, DateTime.now().month, 28),
    notifyEnabled: true,
  );

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flatA);
    store.upsertFlat(flatB);
    store.upsertBed(bed1);
    store.upsertBed(bed2);
    store.upsertBed(bed3);
    store.upsertPerson(person(id: 'p1', name: 'Alice', bedId: 'b1', flatId: 'f1'));
    store.upsertPerson(person(id: 'p2', name: 'Bob', bedId: 'b3', flatId: 'f2'));
    store.upsertPerson(person(id: 'p3', name: 'Carol', bedId: 'b2', flatId: 'f1', archived: true));
  });

  testWidgets('summary cards render values from dashboard_service', (tester) async {
    store.upsertPayment(paymentCurrRent);
    store.upsertPayment(paymentCurrDeposit);
    store.upsertExpense(expenseCurr);
    store.upsertChequeSetting(setting1);
    store.upsertChequeSetting(setting2);

    await pumpDashboard(tester);

    // Flats: 2
    expect(find.text('2'), findsWidgets);
    // Beds: 2/3
    expect(find.text('2/3'), findsOneWidget);
    // Active tenants: 2
    expect(find.text('Active Tenants'), findsOneWidget);
    // Profit: 4000+5000-2000 = 7000
    expect(find.textContaining('AED 7000'), findsOneWidget);
    // Expense: 2000
    expect(find.textContaining('AED 2000'), findsOneWidget);
  });

  testWidgets('who paid shows count summary not full tenant list', (tester) async {
    store.upsertPayment(paymentCurrRent); // only Alice paid

    await pumpDashboard(tester);

    expect(find.text('Who paid this month'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Unpaid'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    // Should NOT show full tenant names list
    expect(find.text('Alice'), findsNothing);
    expect(find.text('Bob'), findsNothing);
  });

  testWidgets('next lease shows exactly one item and tapping navigates', (tester) async {
    store.upsertChequeSetting(setting1); // Mar 15
    store.upsertChequeSetting(setting2); // Feb 28 - earliest

    await pumpDashboard(tester);

    expect(find.text('Next lease payment'), findsOneWidget);
    expect(find.text('Owner B'), findsNothing); // flat name not owner
    expect(find.text('Beta'), findsOneWidget); // flat name from setting2
    expect(find.textContaining('AED 15000'), findsOneWidget);
    expect(find.text('View all lease payments'), findsOneWidget);

    await tester.tap(find.text('View all lease payments'));
    await tester.pumpAndSettle();

    // FlatLeasePaymentScreen shows a list of flats with lease cheques
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('empty state shows zeros and no crash', (tester) async {
    // Fresh store with no data
    final emptyStore = InMemoryJsonStore();

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        onGenerateRoute: buildRoute,
        builder: (context, child) =>
            StoreScope(store: emptyStore, child: child ?? const SizedBox.shrink()),
        home: const DashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsWidgets); // flats, beds, people, profit
    expect(find.text('No lease cheques scheduled.'), findsOneWidget);
  });
}