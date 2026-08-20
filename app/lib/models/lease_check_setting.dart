/// A flat's recurring lease check: money paid OUT to the flat's registered
/// owner, roughly every [intervalMonths] months.
class LeaseCheckSetting {
  const LeaseCheckSetting({
    required this.id,
    required this.flatId,
    required this.ownerName,
    required this.amount,
    required this.nextDueDate,
    this.intervalMonths = 2,
    this.notifyEnabled = true,
  });

  final String id;
  final String flatId;
  final String ownerName;
  final double amount;
  final DateTime nextDueDate;
  final int intervalMonths;
  final bool notifyEnabled;

  LeaseCheckSetting copyWith({
    String? ownerName,
    double? amount,
    DateTime? nextDueDate,
    int? intervalMonths,
    bool? notifyEnabled,
  }) {
    return LeaseCheckSetting(
      id: id,
      flatId: flatId,
      ownerName: ownerName ?? this.ownerName,
      amount: amount ?? this.amount,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
    );
  }

  factory LeaseCheckSetting.fromJson(Map<String, dynamic> json) {
    return LeaseCheckSetting(
      id: json['id'] as String,
      flatId: json['flatId'] as String,
      ownerName: json['ownerName'] as String,
      amount: (json['amount'] as num).toDouble(),
      nextDueDate: DateTime.parse(json['nextDueDate'] as String),
      intervalMonths: (json['intervalMonths'] as num?)?.toInt() ?? 2,
      notifyEnabled: json['notifyEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flatId': flatId,
      'ownerName': ownerName,
      'amount': amount,
      'nextDueDate': nextDueDate.toIso8601String(),
      'intervalMonths': intervalMonths,
      'notifyEnabled': notifyEnabled,
    };
  }
}