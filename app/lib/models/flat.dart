class Flat {
  const Flat({
    required this.id,
    required this.name,
    required this.address,
    required this.createdAt,
    this.contractDate,
    this.contractPerson,
    this.yearlyRent,
  });

  final String id;
  final String name;
  final String address;
  final DateTime createdAt;

  /// When the flat was leased.
  final DateTime? contractDate;

  /// Name the flat is registered/rented under.
  final String? contractPerson;

  /// Total annual lease cost. Drives the auto-calculated cheque amount
  /// (`yearlyRent / 6`), which remains editable afterward.
  final double? yearlyRent;

  Flat copyWith({
    String? id,
    String? name,
    String? address,
    DateTime? createdAt,
    DateTime? contractDate,
    String? contractPerson,
    double? yearlyRent,
  }) {
    return Flat(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      contractDate: contractDate ?? this.contractDate,
      contractPerson: contractPerson ?? this.contractPerson,
      yearlyRent: yearlyRent ?? this.yearlyRent,
    );
  }

  factory Flat.fromJson(Map<String, dynamic> json) {
    return Flat(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      contractDate: json['contractDate'] == null
          ? null
          : DateTime.parse(json['contractDate'] as String),
      contractPerson: json['contractPerson'] as String?,
      yearlyRent: (json['yearlyRent'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'contractDate': contractDate?.toIso8601String(),
      'contractPerson': contractPerson,
      'yearlyRent': yearlyRent,
    };
  }
}