import '../config.dart';

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
    this.description,
    this.paymentMethod,
  });

  final String id;
  final String flatId;
  final String ownerName;
  final double amount;

  /// The date the cheque was scheduled to be handed over.
  final DateTime dueDate;

  /// The date the money actually moved. This is what every month-scoped
  /// financial figure is keyed on, because that is the month the cash left
  /// the account.
  final DateTime paidDate;

  final String? description;
  final String? paymentMethod;

  /// `YYYY-MM` bucket for reports and month navigation.
  ///
  /// Derived from [paidDate] rather than [dueDate] on purpose. A cheque is
  /// routinely paid before it falls due (the schedule always points at the
  /// *next* unmade payment) or after it, so keying on the due date filed the
  /// expense under a month the user never actually paid in — which is what
  /// made historic months look empty. Deriving it here also means an edit to
  /// [paidDate] automatically moves the record to the right month, and any
  /// record already on disk (written with a due-date month) self-corrects the
  /// moment it is read back.
  String get month => monthKey(paidDate);

  LeaseChequeRecord copyWith({
    String? id,
    String? flatId,
    String? ownerName,
    double? amount,
    DateTime? dueDate,
    DateTime? paidDate,
    String? description,
    String? paymentMethod,
    bool clearDescription = false,
    bool clearPaymentMethod = false,
  }) {
    return LeaseChequeRecord(
      id: id ?? this.id,
      flatId: flatId ?? this.flatId,
      ownerName: ownerName ?? this.ownerName,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      description:
          clearDescription ? null : description ?? this.description,
      paymentMethod:
          clearPaymentMethod ? null : paymentMethod ?? this.paymentMethod,
    );
  }

  factory LeaseChequeRecord.fromJson(Map<String, dynamic> json) {
    return LeaseChequeRecord(
      id: json['id'] as String,
      flatId: json['flatId'] as String,
      ownerName: json['ownerName'] as String,
      amount: (json['amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['dueDate'] as String),
      paidDate: DateTime.parse(json['paidDate'] as String),
      description: json['description'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
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
      // Written for readability/compatibility only — [fromJson] derives the
      // bucket from paidDate instead of trusting the stored value.
      'month': month,
      'description': description,
      'paymentMethod': paymentMethod,
    };
  }
}
