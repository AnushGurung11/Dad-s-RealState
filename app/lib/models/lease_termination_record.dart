/// Why a tenant's tenure ended early.
enum TerminationReason {
  financial,
  workplaceChange,
  roommateIssue,
  facilityLacking,
  other;

  static TerminationReason fromString(String value) {
    return TerminationReason.values.firstWhere(
      (r) => r.name == value,
      orElse: () => TerminationReason.other,
    );
  }

  String get label => switch (this) {
        TerminationReason.financial => 'Financial',
        TerminationReason.workplaceChange => 'Workplace change',
        TerminationReason.roommateIssue => 'Roommate issue',
        TerminationReason.facilityLacking => 'Facility lacking',
        TerminationReason.other => 'Other',
      };
}

/// Immutable record of an early termination. The refund is tracked HERE —
/// payment records are never mutated to represent it. Reports must treat
/// [refundAmount] as a deduction from the flat's income for the month it is
/// paid out.
class LeaseTerminationRecord {
  const LeaseTerminationRecord({
    required this.id,
    required this.personId,
    required this.bedId,
    required this.flatId,
    required this.terminationDate,
    required this.reason,
    this.reasonNote,
    required this.totalPaidAcrossPrepaidMonths,
    required this.daysStayedFinalMonth,
    required this.earnedFinalMonth,
    required this.refundAmount,
  });

  final String id;
  final String personId;
  final String bedId;
  final String flatId;
  final DateTime terminationDate;
  final TerminationReason reason;

  /// Required when reason == other, optional otherwise ("why" color).
  final String? reasonNote;

  /// Sum of every rent payment covering the current + future prepaid months
  /// at the moment of termination.
  final double totalPaidAcrossPrepaidMonths;

  /// Days actually lived in the termination month (terminationDate.day).
  final int daysStayedFinalMonth;

  /// Prorated rent earned for those days: days/daysInMonth × monthlyRent.
  final double earnedFinalMonth;

  /// Money returned to the tenant: unused portion of the final month plus
  /// all fully-unearned future prepaid months. Never negative.
  final double refundAmount;

  LeaseTerminationRecord copyWith({
    String? id,
    String? personId,
    String? bedId,
    String? flatId,
    DateTime? terminationDate,
    TerminationReason? reason,
    String? reasonNote,
    double? totalPaidAcrossPrepaidMonths,
    int? daysStayedFinalMonth,
    double? earnedFinalMonth,
    double? refundAmount,
  }) {
    return LeaseTerminationRecord(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      bedId: bedId ?? this.bedId,
      flatId: flatId ?? this.flatId,
      terminationDate: terminationDate ?? this.terminationDate,
      reason: reason ?? this.reason,
      reasonNote: reasonNote ?? this.reasonNote,
      totalPaidAcrossPrepaidMonths:
          totalPaidAcrossPrepaidMonths ?? this.totalPaidAcrossPrepaidMonths,
      daysStayedFinalMonth:
          daysStayedFinalMonth ?? this.daysStayedFinalMonth,
      earnedFinalMonth: earnedFinalMonth ?? this.earnedFinalMonth,
      refundAmount: refundAmount ?? this.refundAmount,
    );
  }

  factory LeaseTerminationRecord.fromJson(Map<String, dynamic> json) {
    return LeaseTerminationRecord(
      id: json['id'] as String,
      personId: json['personId'] as String,
      bedId: json['bedId'] as String,
      flatId: json['flatId'] as String,
      terminationDate: DateTime.parse(json['terminationDate'] as String),
      reason: TerminationReason.fromString(json['reason'] as String),
      reasonNote: json['reasonNote'] as String?,
      totalPaidAcrossPrepaidMonths:
          (json['totalPaidAcrossPrepaidMonths'] as num).toDouble(),
      daysStayedFinalMonth: (json['daysStayedFinalMonth'] as num).toInt(),
      earnedFinalMonth: (json['earnedFinalMonth'] as num).toDouble(),
      refundAmount: (json['refundAmount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'personId': personId,
      'bedId': bedId,
      'flatId': flatId,
      'terminationDate': terminationDate.toIso8601String(),
      'reason': reason.name,
      'reasonNote': reasonNote,
      'totalPaidAcrossPrepaidMonths': totalPaidAcrossPrepaidMonths,
      'daysStayedFinalMonth': daysStayedFinalMonth,
      'earnedFinalMonth': earnedFinalMonth,
      'refundAmount': refundAmount,
    };
  }
}
