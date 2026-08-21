import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/expense.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/lease_cheque_setting.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/dashboard_service.dart';

void main() {
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

  final bed1 = Bed(id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000, tenantId: 'p1');
  final bed2 = Bed(id: 'b2', flatId: 'f1', label: 'Bed 2', defaultMonthlyRent: 4000, tenantId: null);
  final bed3 = Bed(id: 'b3', flatId: 'f2', label: 'Bed 1', defaultMonthlyRent: 4500, tenantId: 'p2');

  final p1 = Person(
    id: 'p1',
    name: 'Alice',
    contact: '9000000001',
    bedId: 'b1',
    flatId: 'f1',
    joinDate: DateTime(2026, 1, 1),
    plannedStayMonths: 12,
    depositAmount: 5000,
    monthlyRent: 4000,
  );
  final p2 = Person(
    id: 'p2',
    name: 'Bob',
    contact: '9000000002',
    bedId: 'b3',
    flatId: 'f2',
    joinDate: DateTime(2026, 1, 1),
    plannedStayMonths: 12,
    depositAmount: 5000,
    monthlyRent: 4500,
  );
  final p3 = Person(
    id: 'p3',
    name: 'Carol',
    contact: '9000000003',
    bedId: 'b2',
    flatId: 'f1',
    joinDate: DateTime(2026, 1, 1),
    plannedStayMonths: 12,
    depositAmount: 5000,
    monthlyRent: 4000,
    archived: true,
  );

  const paymentFebRent = Payment(
    id: 'pay1',
    personId: 'p1',
    bedId: 'b1',
    flatId: 'f1',
    month: '2026-02',
    amountDue: 4000,
    amountPaid: 4000,
    type: PaymentType.rent,
  );
  const paymentFebDeposit = Payment(
    id: 'pay2',
    personId: 'p1',
    bedId: 'b1',
    flatId: 'f1',
    month: '2026-02',
    amountDue: 5000,
    amountPaid: 5000,
    type: PaymentType.deposit,
  );
  const paymentJanRent = Payment(
    id: 'pay3',
    personId: 'p2',
    bedId: 'b3',
    flatId: 'f2',
    month: '2026-01',
    amountDue: 4500,
    amountPaid: 4500,
    type: PaymentType.rent,
  );

  final expenseFeb = Expense(
    id: 'e1',
    flatId: 'f1',
    category: ExpenseCategory.electricity,
    amount: 2000,
    date: DateTime(2026, 2, 10),
  );
  final expenseJan = Expense(
    id: 'e2',
    flatId: 'f1',
    category: ExpenseCategory.water,
    amount: 500,
    date: DateTime(2026, 1, 15),
  );

  final setting1 = LeaseChequeSetting(
    id: 's1',
    flatId: 'f1',
    ownerName: 'Owner A',
    amount: 12000,
    nextDueDate: DateTime(2026, 3, 15),
    notifyEnabled: true,
  );
  final setting2 = LeaseChequeSetting(
    id: 's2',
    flatId: 'f2',
    ownerName: 'Owner B',
    amount: 15000,
    nextDueDate: DateTime(2026, 2, 28),
    notifyEnabled: true,
  );

  test('counts match fixture data exactly', () {
    final summary = DashboardService().build(
      flats: [flatA, flatB],
      beds: [bed1, bed2, bed3],
      people: [p1, p2, p3],
      payments: [],
      expenses: [],
      leaseSettings: [],
      month: '2026-02',
    );

    expect(summary.flatsCount, 2);
    expect(summary.bedsOccupied, 2);
    expect(summary.bedsVacant, 1);
    expect(summary.activePeopleCount, 2); // p3 archived excluded
  });

  test('monthProfit nets payments against expenses for given month only', () {
    final summary = DashboardService().build(
      flats: [flatA, flatB],
      beds: [bed1, bed2, bed3],
      people: [p1, p2, p3],
      payments: [paymentFebRent, paymentFebDeposit, paymentJanRent],
      expenses: [expenseFeb, expenseJan],
      leaseSettings: [],
      month: '2026-02',
    );

    // Feb: rent 4000 + deposit 5000 = 9000 income; expense 2000
    // Profit = 9000 - 2000 = 7000
    expect(summary.monthProfit, 7000);
    expect(summary.monthExpense, 2000);
  });

  test('archived people excluded from active count and who-paid denominator', () {
    final summary = DashboardService().build(
      flats: [flatA, flatB],
      beds: [bed1, bed2, bed3],
      people: [p1, p2, p3],
      payments: [paymentFebRent], // p1 paid
      expenses: [],
      leaseSettings: [],
      month: '2026-02',
    );

    expect(summary.activePeopleCount, 2);
    expect(summary.totalActiveTenantCount, 2);
    expect(summary.paidThisMonthCount, 1); // only p1 paid
  });

  test('nextLeasePayment picks earliest nextDueDate', () {
    final summary = DashboardService().build(
      flats: [flatA, flatB],
      beds: [bed1, bed2, bed3],
      people: [p1, p2, p3],
      payments: [],
      expenses: [],
      leaseSettings: [setting1, setting2],
      month: '2026-02',
    );

    // setting2 is Feb 28, setting1 is Mar 15 -> setting2 wins
    expect(summary.nextLeasePayment?.id, 's2');
    expect(summary.nextLeasePayment?.flatId, 'f2');
  });

  test('nextLeasePayment returns null when no settings', () {
    final summary = DashboardService().build(
      flats: [flatA, flatB],
      beds: [bed1, bed2, bed3],
      people: [p1, p2, p3],
      payments: [],
      expenses: [],
      leaseSettings: [],
      month: '2026-02',
    );

    expect(summary.nextLeasePayment, isNull);
  });

  test('tenant with partial payment counts as paid (any rent record in month)', () {
    const partialPayment = Payment(
      id: 'pay4',
      personId: 'p2',
      bedId: 'b3',
      flatId: 'f2',
      month: '2026-02',
      amountDue: 4500,
      amountPaid: 1000, // partial
      type: PaymentType.rent,
    );

    final summary = DashboardService().build(
      flats: [flatA, flatB],
      beds: [bed1, bed2, bed3],
      people: [p1, p2, p3],
      payments: [partialPayment],
      expenses: [],
      leaseSettings: [],
      month: '2026-02',
    );

    expect(summary.paidThisMonthCount, 1); // p2 counted despite partial
  });

  test('payments outside the month are excluded', () {
    final summary = DashboardService().build(
      flats: [flatA, flatB],
      beds: [bed1, bed2, bed3],
      people: [p1, p2, p3],
      payments: [paymentJanRent], // Jan payment
      expenses: [expenseJan], // Jan expense
      leaseSettings: [],
      month: '2026-02', // looking at Feb
    );

    expect(summary.monthProfit, 0);
    expect(summary.monthExpense, 0);
    expect(summary.paidThisMonthCount, 0);
  });
}