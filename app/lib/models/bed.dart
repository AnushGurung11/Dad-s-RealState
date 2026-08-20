class Bed {
  const Bed({
    required this.id,
    required this.flatId,
    required this.label,
    required this.defaultMonthlyRent,
    this.tenantId,
  });

  final String id;
  final String flatId;
  final String label;

  /// The rent this bed rents for by default. Pre-fills a tenant's
  /// [Person.monthlyRent] at assignment, but is editable per-person — not a
  /// hard rule.
  final double defaultMonthlyRent;

  final String? tenantId;

  Bed copyWith({
    String? id,
    String? flatId,
    String? label,
    double? defaultMonthlyRent,
    String? tenantId,
    bool clearTenantId = false,
  }) {
    return Bed(
      id: id ?? this.id,
      flatId: flatId ?? this.flatId,
      label: label ?? this.label,
      defaultMonthlyRent: defaultMonthlyRent ?? this.defaultMonthlyRent,
      tenantId: clearTenantId ? null : tenantId ?? this.tenantId,
    );
  }

  bool get isOccupied => tenantId != null;

  factory Bed.fromJson(Map<String, dynamic> json) {
    return Bed(
      id: json['id'] as String,
      flatId: json['flatId'] as String,
      label: json['label'] as String,
      // Older builds stored the default rent under `monthlyRent`.
      defaultMonthlyRent:
          ((json['defaultMonthlyRent'] ?? json['monthlyRent']) as num)
              .toDouble(),
      tenantId: json['tenantId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flatId': flatId,
      'label': label,
      'defaultMonthlyRent': defaultMonthlyRent,
      'tenantId': tenantId,
    };
  }
}