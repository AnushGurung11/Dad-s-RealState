class Bed {
  const Bed({
    required this.id,
    required this.flatId,
    required this.label,
    required this.monthlyRent,
    this.tenantId,
  });

  final String id;
  final String flatId;
  final String label;
  final double monthlyRent;
  final String? tenantId;

  Bed copyWith({
    String? id,
    String? flatId,
    String? label,
    double? monthlyRent,
    String? tenantId,
    bool clearTenantId = false,
  }) {
    return Bed(
      id: id ?? this.id,
      flatId: flatId ?? this.flatId,
      label: label ?? this.label,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      tenantId: clearTenantId ? null : tenantId ?? this.tenantId,
    );
  }

  bool get isOccupied => tenantId != null;

  factory Bed.fromJson(Map<String, dynamic> json) {
    return Bed(
      id: json['id'] as String,
      flatId: json['flatId'] as String,
      label: json['label'] as String,
      monthlyRent: (json['monthlyRent'] as num).toDouble(),
      tenantId: json['tenantId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flatId': flatId,
      'label': label,
      'monthlyRent': monthlyRent,
      'tenantId': tenantId,
    };
  }
}