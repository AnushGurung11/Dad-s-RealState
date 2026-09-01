import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/main.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/lease_cheque_setting.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/services/json_store.dart';

/// End-to-end dashboard verification: fixtures spanning two months,
/// Dashboard should only show current month figures.
void main() {
  testWidgets('dashboard reflects only current month data', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    final currMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha',
      address: '1 A Road',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertBed(const Bed(
        id: 'b1',
        flatId: 'f1',
        label: 'Bed 1',
        defaultMonthlyRent: 4000,
        tenantId: 'p1'));
    store.upsertBed(const Bed(
        id: 'b2',
        flatId: 'f1',
        label: 'Bed 2',
        defaultMonthlyRent: 4000,
        tenantId: 'p2'));
    store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      contact: '9000000001',
      bedId: 'b1',
      flatId: 'f1',
      joinDate: DateTime(now.year, now.month - 1, now.day),
      plannedStayMonths: 12,
      depositAmount: 5000,
      monthlyRent: 4000,
    ));
    store.upsertPerson(Person(
      id: 'p2',
      name: 'Bob',
      contact: '9000000002',
      bedId: 'b2',
      flatId: 'f1',
      joinDate: DateTime(now.year, now.month - 1, now.day),
      plannedStayMonths: 12,
      depositAmount: 5000,
      monthlyRent: 4000,
    ));

    // Payments: one in current month, one in previous month
    store.upsertPayment(Payment(
      id: 'pay_curr',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: currMonthKey,
      amountDue: 4000,
      amountPaid: 4000,
      type: PaymentType.rent,
    ));
    store.upsertPayment(Payment(
      id: 'pay_prev',
      personId: 'p2',
      bedId: 'b2',
      flatId: 'f1',
      month: '${prevMonth.year}-${prevMonth.month.toString().padLeft(2, '0')}',
      amountDue: 4000,
      amountPaid: 4000,
      type: PaymentType.rent,
    ));
    // Deposit in current month
    store.upsertPayment(Payment(
      id: 'dep_curr',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: currMonthKey,
      amountDue: 5000,
      amountPaid: 5000,
      type: PaymentType.deposit,
    ));

    // Expenses: one in current month, one in previous
    store.upsertExpense(Expense(
      id: 'exp_curr',
      flatId: 'f1',
      category: ExpenseCategory.electricity,
      amount: 2000,
      date: DateTime(now.year, now.month, 5),
    ));
    store.upsertExpense(Expense(
      id: 'exp_prev',
      flatId: 'f1',
      category: ExpenseCategory.water,
      amount: 500,
      date: DateTime(prevMonth.year, prevMonth.month, 10),
    ));

    // Lease settings
    store.upsertChequeSetting(LeaseChequeSetting(
      id: 's1',
      flatId: 'f1',
      ownerName: 'Owner A',
      amount: 12000,
      nextDueDate: DateTime(now.year, now.month + 1, 15),
      notifyEnabled: true,
    ));

    await tester.pumpWidget(LuckyApp(createStore: () => store));
    await tester.pumpAndSettle();

    // ── Verify Dashboard shows ONLY current month figures ─────────────
    // Flats: 1
    expect(find.text('1'), findsWidgets);
    // Occupancy: 2/2 (both occupied)
    expect(find.text('2/2'), findsOneWidget);
    // Active tenants card removed
    expect(find.text('Active Tenants'), findsNothing);

    // Profit: current month rent (4000) + deposit (5000) - expense (2000) = 7000
    // NOT including previous month's 4000 rent.
    expect(find.textContaining('7000 AED'), findsOneWidget);
    // New dashboard has Next Lease Due card and Recent Transactions
    expect(find.text('Next Lease Due'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);
    // Old payment buttons removed
    expect(
        find.byKey(const Key('dashboard_lease_payment_button')),
        findsNothing);
    expect(
        find.byKey(const Key('dashboard_rent_payment_button')),
        findsNothing);
    // Occupancy and Profit+Expense card should be present - check via keys to avoid bottom nav duplicate
    expect(find.byKey(const Key('dashboard_flats_card')), findsOneWidget);
    expect(find.byKey(const Key('dashboard_occupancy_card')), findsOneWidget);
    expect(find.byKey(const Key('profit_expense_card')), findsOneWidget);
  });
}