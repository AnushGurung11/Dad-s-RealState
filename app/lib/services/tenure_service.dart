import '../models/payment.dart';
import '../models/person.dart';

/// Pure tenure math per tenant. No I/O; fixture-testable.
abstract final class TenureService {
  /// Leave date computed from the plan: joinDate + plannedStayMonths.
  static DateTime computedLeaveDate(DateTime joinDate, int plannedStayMonths) {
    return DateTime(joinDate.year, joinDate.month + plannedStayMonths, joinDate.day);
  }

  /// Months the tenant is charged for. Normally [Person.plannedStayMonths],
  /// but if [Person.vacatedDate] was edited to differ from the plan, the actual
  /// months between joinDate and leaveDate are used (rounded up, minimum 1).
  static int effectiveStayMonths(Person person) {
    final planned = person.plannedStayMonths ?? 1;
    final join = person.joinDate ?? DateTime.now();
    final leave = person.vacatedDate ?? computedLeaveDate(join, planned);
    final plannedLeave = computedLeaveDate(join, planned);
    final sameDate = leave.year == plannedLeave.year && leave.month == plannedLeave.month && leave.day == plannedLeave.day;
    if (sameDate) return planned;

    var months = (leave.year - join.year) * 12 + (leave.month - join.month);
    if (leave.day > join.day) months += 1;
    return months < 1 ? 1 : months;
  }

  /// Total rent owed over the tenure: monthlyRent × effective stay months.
  static double totalRentOwed(Person person, double monthlyRent) {
    return monthlyRent * effectiveStayMonths(person);
  }

  /// Remaining balance = totalRentOwed − deposit − sum of rent payments made.
  static double remainingBalance(
    Person person,
    double monthlyRent,
    List<Payment> payments,
  ) {
    final rentPaid = payments
        .where((p) => p.personId == person.id && p.type == PaymentType.rent)
        .fold(0.0, (sum, p) => sum + p.amountPaid);
    return totalRentOwed(person, monthlyRent) -
        (person.depositAmount ?? 0) -
        rentPaid;
  }
}