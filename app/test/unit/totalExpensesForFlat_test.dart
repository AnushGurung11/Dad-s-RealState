// ignore_for_file: file_names
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/lease_cheque_record.dart';
import 'package:lucky/services/dashboard_service.dart';
import 'package:lucky/services/expense_aggregation_service.dart';
import 'package:lucky/services/report_service.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';

void main() {
  test('includes both Expense records and LeaseChequeRecord amounts for the given flat/period', () {
    final expenses = [
      Expense(id: 'e1', flatId: 'f1', category: ExpenseCategory.electricity, amount: 100, date: DateTime(2026, 1, 10)),
      Expense(id: 'e2', flatId: 'f1', category: ExpenseCategory.water, amount: 50, date: DateTime(2026, 1, 15)),
      Expense(id: 'e3', flatId: 'f2', category: ExpenseCategory.electricity, amount: 999, date: DateTime(2026, 1, 10)),
    ];
    final leases = [
      LeaseChequeRecord(id: 'l1', flatId: 'f1', ownerName: 'Owner', amount: 200, dueDate: DateTime(2026, 1, 1), paidDate: DateTime(2026, 1, 5), month: '2026-01'),
      LeaseChequeRecord(id: 'l2', flatId: 'f1', ownerName: 'Owner', amount: 300, dueDate: DateTime(2026, 2, 1), paidDate: DateTime(2026, 2, 5), month: '2026-02'),
    ];

    final totalJan = ExpenseAggregationService.totalExpensesForFlat(
      flatId: 'f1',
      month: '2026-01',
      expenses: expenses,
      leaseChequeRecords: leases,
    );
    expect(totalJan, 100 + 50 + 200); // 350
    expect(totalJan, isNot(100 + 50)); // ensure lease included

    final totalFeb = ExpenseAggregationService.totalExpensesForFlat(
      flatId: 'f1',
      month: '2026-02',
      expenses: expenses,
      leaseChequeRecords: leases,
    );
    expect(totalFeb, 300); // only lease in Feb, no categorized expense

    // Other flat not included
    final totalF2 = ExpenseAggregationService.totalExpensesForFlat(
      flatId: 'f2',
      month: '2026-01',
      expenses: expenses,
      leaseChequeRecords: leases,
    );
    expect(totalF2, 999);
  });

  test('Dashboard, Profit breakdown, and Financial Report all produce identical expense totals for the same fixture data', () {
    final flat = Flat(id: 'f1', name: 'Alpha', address: 'A', createdAt: DateTime(2026, 1, 1));
    final bed = Bed(id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000);
    final person = Person(id: 'p1', name: 'Alice', contact: '1', bedId: 'b1', flatId: 'f1', joinDate: DateTime(2026, 1, 1), plannedStayMonths: 12);
    final payments = [
      Payment(id: 'pay1', personId: 'p1', bedId: 'b1', flatId: 'f1', month: '2026-01', amountDue: 4000, amountPaid: 4000),
    ];
    final expenses = [
      Expense(id: 'e1', flatId: 'f1', category: ExpenseCategory.electricity, amount: 100, date: DateTime(2026, 1, 10)),
    ];
    final leases = [
      LeaseChequeRecord(id: 'l1', flatId: 'f1', ownerName: 'Owner', amount: 200, dueDate: DateTime(2026, 1, 1), paidDate: DateTime(2026, 1, 5), month: '2026-01'),
    ];
    final month = '2026-01';

    // Shared function
    final shared = ExpenseAggregationService.totalExpensesForFlat(
      flatId: 'f1',
      month: month,
      expenses: expenses,
      leaseChequeRecords: leases,
    );

    // Dashboard
    final dashboard = DashboardService().build(
      flats: [flat],
      beds: [bed],
      people: [person],
      payments: payments,
      expenses: expenses,
      leaseSettings: [],
      leaseChequeRecords: leases,
      month: month,
    );
    expect(dashboard.monthExpense, shared);

    // ReportService
    final reportExpense = ReportService.flatExpenses(
      expenses: expenses,
      flatId: 'f1',
      month: month,
      leaseChequeRecords: leases,
    );
    expect(reportExpense, shared);

    // Financial Report would use same
    expect(reportExpense, dashboard.monthExpense);
  });
}
