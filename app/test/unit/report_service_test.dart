import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/expense.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/services/report_service.dart';

const rentFeb = Payment(
  id: 'r1',
  personId: 'personA',
  bedId: 'b1',
  flatId: 'f1',
  month: '2026-02',
  amountDue: 4000,
  amountPaid: 4000,
);
const rentFebPartial = Payment(
  id: 'r2',
  personId: 'personB',
  bedId: 'b2',
  flatId: 'f1',
  month: '2026-02',
  amountDue: 4000,
  amountPaid: 1500,
);
const depositFeb = Payment(
  id: 'd1',
  personId: 'personA',
  bedId: 'b1',
  flatId: 'f1',
  month: '2026-02',
  amountDue: 5000,
  amountPaid: 5000,
  type: PaymentType.deposit,
);
const rentJan = Payment(
  id: 'r3',
  personId: 'personA',
  bedId: 'b1',
  flatId: 'f1',
  month: '2026-01',
  amountDue: 4000,
  amountPaid: 4000,
);
const rentOtherFlat = Payment(
  id: 'r4',
  personId: 'personC',
  bedId: 'b3',
  flatId: 'f2',
  month: '2026-02',
  amountDue: 5000,
  amountPaid: 5000,
);

final electricityFeb = Expense(
  id: 'e1',
  flatId: 'f1',
  category: ExpenseCategory.electricity,
  amount: 2000,
  date: DateTime(2026, 2, 10),
);
final maintenanceFeb = Expense(
  id: 'e2',
  flatId: 'f1',
  category: ExpenseCategory.maintenance,
  amount: 3500,
  date: DateTime(2026, 2, 20),
);
final waterJan = Expense(
  id: 'e3',
  flatId: 'f1',
  category: ExpenseCategory.water,
  amount: 500,
  date: DateTime(2026, 1, 15),
);
final gasOtherFlat = Expense(
  id: 'e4',
  flatId: 'f2',
  category: ExpenseCategory.gas,
  amount: 800,
  date: DateTime(2026, 2, 5),
);

void main() {
  const allPayments = [rentFeb, rentFebPartial, depositFeb, rentJan, rentOtherFlat];
  final allExpenses = [electricityFeb, maintenanceFeb, waterJan, gasOtherFlat];

  group('ReportService.flatIncome', () {
    test('sums rent payments + deposits in the period only', () {
      final income = ReportService.flatIncome(
        payments: allPayments,
        flatId: 'f1',
        month: '2026-02',
      );
      // 4000 + 1500 + 5000 = 10500; January and other-flat records excluded.
      expect(income, 10500);
    });

    test('returns zero when no payments match the period', () {
      final income = ReportService.flatIncome(
        payments: allPayments,
        flatId: 'f1',
        month: '2026-03',
      );
      expect(income, 0);
    });
  });

  group('ReportService.flatExpenses', () {
    test('sums expenses in the period only, by flat', () {
      final expenses = ReportService.flatExpenses(
        expenses: allExpenses,
        flatId: 'f1',
        month: '2026-02',
      );
      // 2000 + 3500 = 5500
      expect(expenses, 5500);
    });

    test('returns zero when no expenses match', () {
      expect(
        ReportService.flatExpenses(
          expenses: allExpenses,
          flatId: 'f1',
          month: '2026-06',
        ),
        0,
      );
    });
  });

  group('ReportService.flatNet', () {
    test('negative when expenses > income', () {
      final net = ReportService.flatNet(
        payments: const [rentFebPartial],
        expenses: [maintenanceFeb],
        flatId: 'f1',
        month: '2026-02',
      );
      expect(net, -2000);
    });

    test('positive when income > expenses', () {
      final net = ReportService.flatNet(
        payments: allPayments,
        expenses: [electricityFeb],
        flatId: 'f1',
        month: '2026-02',
      );
      expect(net, 8500);
    });

    test('empty flat edge case returns zero, not null or crash', () {
      final summary = ReportService.flatSummary(
        payments: const [],
        expenses: const [],
        flatId: 'missing',
        month: '2026-02',
      );
      expect(summary.income, 0);
      expect(summary.expenses, 0);
      expect(summary.net, 0);
    });
  });

  group('ReportService.dashboardTotals', () {
    test('sums across all flats for a month', () {
      final totals = ReportService.dashboardTotals(
        payments: allPayments,
        expenses: allExpenses,
        month: '2026-02',
      );
      // income: 4000 + 1500 + 5000 + 5000 = 15500
      // expenses: 2000 + 3500 + 800 = 6300
      expect(totals.income, 15500);
      expect(totals.expenses, 6300);
      expect(totals.net, 9200);
    });

    test('empty data returns zero totals', () {
      final totals = ReportService.dashboardTotals(
        payments: const [],
        expenses: const [],
        month: '2026-02',
      );
      expect(totals.income, 0);
      expect(totals.expenses, 0);
      expect(totals.net, 0);
    });
  });

  group('ReportService.monthlyIncome', () {
    test('rolls income up per month for a flat', () {
      final rollup = ReportService.monthlyIncome(
        payments: allPayments,
        flatId: 'f1',
      );
      expect(rollup['2026-01'], 4000);
      expect(rollup['2026-02'], 10500);
    });
  });
}