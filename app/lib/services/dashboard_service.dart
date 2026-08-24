import '../models/bed.dart';
import '../models/flat.dart';
import '../models/lease_cheque_setting.dart';
import '../models/payment.dart';
import '../models/person.dart';
import '../models/expense.dart';
import '../config.dart';

/// Aggregated dashboard data for a given month (YYYY-MM).
class DashboardSummary {
  const DashboardSummary({
    required this.flatsCount,
    required this.bedsOccupied,
    required this.bedsVacant,
    required this.activePeopleCount,
    required this.monthProfit,
    required this.monthExpense,
    required this.paidThisMonthCount,
    required this.totalActiveTenantCount,
    required this.nextLeasePayment,
  });

  final int flatsCount;
  final int bedsOccupied;
  final int bedsVacant;
  final int activePeopleCount;
  final double monthProfit;
  final double monthExpense;
  final int paidThisMonthCount;
  final int totalActiveTenantCount;
  final LeaseChequeSetting? nextLeasePayment;
}

/// Pure dashboard aggregation — no I/O, unit-testable with fixtures.
class DashboardService {
  const DashboardService();

  /// Builds a summary for [month] (YYYY-MM). If [month] is null, uses current month.
  DashboardSummary build({
    required List<Flat> flats,
    required List<Bed> beds,
    required List<Person> people,
    required List<Payment> payments,
    required List<Expense> expenses,
    required List<LeaseChequeSetting> leaseSettings,
    String? month,
  }) {
    final m = month ?? monthKey(DateTime.now());

    // Filter out archived flats and their beds
    final activeFlats = flats.where((f) => !f.archived).toList();
    final activeFlatIds = activeFlats.map((f) => f.id).toSet();
    final activeBeds = beds.where((b) => activeFlatIds.contains(b.flatId)).toList();
    final activeLeaseSettings = leaseSettings.where((s) => activeFlatIds.contains(s.flatId)).toList();

    // Beds
    final occupied = activeBeds.where((b) => b.tenantId != null).length;
    final vacant = activeBeds.where((b) => b.tenantId == null).length;

    // People: active tenants only (only those in active flats)
    final activePeople = people
        .where((p) => p.isActiveTenant && p.status == PersonStatus.active && activeFlatIds.contains(p.flatId))
        .toList();

    // Expenses in month (only for active flats)
    final activeExpenseFlatIds = expenses
        .where((e) => monthKey(e.date) == m && activeFlatIds.contains(e.flatId))
        .map((e) => e.flatId)
        .toSet();
    final monthExpenses = expenses
        .where((e) => monthKey(e.date) == m && activeFlatIds.contains(e.flatId))
        .toList();
    final monthExpenseTotal = monthExpenses.fold(0.0, (sum, e) => sum + e.amount);

    // Payments in month: rent + deposit (only for active flats)
    final monthPayments = payments
        .where((p) =>
            p.month == m &&
            (p.type == PaymentType.rent || p.type == PaymentType.deposit) &&
            activeFlatIds.contains(p.flatId))
        .toList();
    final monthIncome = monthPayments.fold(0.0, (sum, p) => sum + p.amountPaid);

    // Who paid this month: active tenants with at least one rent payment in month
    final paidPersonIds = monthPayments
        .where((p) => p.type == PaymentType.rent)
        .map((p) => p.personId)
        .toSet();
    final paidCount = activePeople.where((p) => paidPersonIds.contains(p.id)).length;
    final totalActiveTenantCount = activePeople.length;

    // Next lease payment: earliest nextDueDate (only for active flats)
    LeaseChequeSetting? nextLease;
    if (activeLeaseSettings.isNotEmpty) {
      final sorted = [...activeLeaseSettings]
        ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
      nextLease = sorted.first;
    }

    return DashboardSummary(
      flatsCount: activeFlats.length,
      bedsOccupied: occupied,
      bedsVacant: vacant,
      activePeopleCount: activePeople.length,
      monthProfit: monthIncome - monthExpenseTotal,
      monthExpense: monthExpenseTotal,
      paidThisMonthCount: paidCount,
      totalActiveTenantCount: totalActiveTenantCount,
      nextLeasePayment: nextLease,
    );
  }
}