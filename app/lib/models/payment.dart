enum PaymentStatus {
  paid,
  partial,
  unpaid;

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PaymentStatus.unpaid,
    );
  }
}

enum PaymentType {
  rent,
  deposit;

  static PaymentType fromString(String value) {
    return PaymentType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => PaymentType.rent,
    );
  }
}

class Payment {
  const Payment({
    required this.id,
    required this.personId,
    required this.bedId,
    required this.flatId,
    required this.month,
    required this.amountDue,
    required this.amountPaid,
    this.type = PaymentType.rent,
  });

  final String id;
  final String personId;
  final String bedId;
  final String flatId;

  /// Month in YYYY-MM format.
  final String month;
  final double amountDue;
  final double amountPaid;

  /// Distinguishes rent from deposits in the single ledger. Both count as
  /// income, but only rent reduces the tenure balance.
  final PaymentType type;

  PaymentStatus get status {
    if (amountPaid <= 0) return PaymentStatus.unpaid;
    if (amountPaid >= amountDue) return PaymentStatus.paid;
    return PaymentStatus.partial;
  }

  Payment copyWith({
    String? id,
    String? personId,
    String? bedId,
    String? flatId,
    String? month,
    double? amountDue,
    double? amountPaid,
    PaymentType? type,
  }) {
    return Payment(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      bedId: bedId ?? this.bedId,
      flatId: flatId ?? this.flatId,
      month: month ?? this.month,
      amountDue: amountDue ?? this.amountDue,
      amountPaid: amountPaid ?? this.amountPaid,
      type: type ?? this.type,
    );
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      personId: json['personId'] as String,
      bedId: json['bedId'] as String,
      flatId: json['flatId'] as String,
      month: json['month'] as String,
      amountDue: (json['amountDue'] as num).toDouble(),
      amountPaid: (json['amountPaid'] as num).toDouble(),
      type: PaymentType.fromString(json['type'] as String? ?? 'rent'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'personId': personId,
      'bedId': bedId,
      'flatId': flatId,
      'month': month,
      'amountDue': amountDue,
      'amountPaid': amountPaid,
      'type': type.name,
    };
  }
}