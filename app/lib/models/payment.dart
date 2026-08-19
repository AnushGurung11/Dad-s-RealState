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

class Payment {
  const Payment({
    required this.id,
    required this.personId,
    required this.bedId,
    required this.flatId,
    required this.month,
    required this.amountDue,
    required this.amountPaid,
  });

  final String id;
  final String personId;
  final String bedId;
  final String flatId;

  /// Month in YYYY-MM format.
  final String month;
  final double amountDue;
  final double amountPaid;

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
  }) {
    return Payment(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      bedId: bedId ?? this.bedId,
      flatId: flatId ?? this.flatId,
      month: month ?? this.month,
      amountDue: amountDue ?? this.amountDue,
      amountPaid: amountPaid ?? this.amountPaid,
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
    };
  }
}