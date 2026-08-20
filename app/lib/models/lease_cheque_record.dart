/// Immutable history entry created when a lease cheque is marked paid.
/// Used by financial reports, so it is queryable by month and flat.
class LeaseChequeRecord {
  const LeaseChequeRecord({
    required this.id,
    required this.flatId,
    required this.ownerName,
    required this.amount,
    required this.dueDate,
    required this.paidDate,
    required this.month,
  });

  final String id;
  final String flatId;
  final String ownerName;
  final double amount;
  final DateTime dueDate;
  final DateTime paidDate;

  /// `YYYY-MM` of the due date, for report lookups.
  final String month;

  factory LeaseChequeRecord.fromJson(Map<String, dynamic> json) {
    return LeaseChequeRecord(
      id: json['id'] as String,
      flatId: json['flatId'] as String,
      ownerName: json['ownerName'] as String,
      amount: (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['dueDate'] as String),
      paidDate: DateTime.parse(json['paidDate'] as String),
      month: json['month'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flatId': flatId,
      'ownerName': ownerName,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'paidDate': paidDate.toIso8601String(),
      'month': month,
    };
  }
}