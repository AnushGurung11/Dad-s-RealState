class Flat {
  const Flat({
    required this.id,
    required this.name,
    required this.address,
    required this.createdAt,
    this.registeredDate,
    this.contractPerson,
    this.yearlyRent,
    this.archived = false,
    this.archivedAt,
    this.leasePaidThroughDate,
    this.frequencyMonths = 2,
  });

  final String id;
  final String name;
  final String address;
  final DateTime createdAt;

  /// When the flat was registered with its owner. Explicitly NOT a lease
  /// payment date — cheque due dates live on [LeaseChequeSetting].
  final DateTime? registeredDate;

  /// Name the flat is registered/rented under.
  final String? contractPerson;

  /// Total annual lease cost. Drives the auto-calculated cheque amount
  /// (`yearlyRent / (12 / frequencyMonths)`), which remains editable afterward.
  final double? yearlyRent;

  /// Soft-delete marker. Archived flats keep every bed and historical
  /// occupant link for reporting but are no longer assignable, and they move
  /// out of the main Flats grid into the Archive Flats screen.
  final bool archived;

  /// When the flat was archived.
  final DateTime? archivedAt;

  /// Onboarding field: lease is paid up through this date. If set, the auto-
  /// created LeaseChequeSetting.nextDueDate starts from this date instead of
  /// registeredDate + frequencyMonths. Optional — leave blank for a genuinely
  /// new lease.
  final DateTime? leasePaidThroughDate;

  /// How many months between lease payments. Defaults to 2 (bi-monthly).
  final int frequencyMonths;

  Flat copyWith({
    String? id,
    String? name,
    String? address,
    DateTime? createdAt,
    DateTime? registeredDate,
    String? contractPerson,
    double? yearlyRent,
    bool? archived,
    DateTime? archivedAt,
    bool clearRegisteredDate = false,
    DateTime? leasePaidThroughDate,
    bool clearLeasePaidThroughDate = false,
    int? frequencyMonths,
  }) {
    return Flat(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      registeredDate:
          clearRegisteredDate ? null : registeredDate ?? this.registeredDate,
      contractPerson: contractPerson ?? this.contractPerson,
      yearlyRent: yearlyRent ?? this.yearlyRent,
      archived: archived ?? this.archived,
      archivedAt: archivedAt ?? this.archivedAt,
      leasePaidThroughDate:
          clearLeasePaidThroughDate ? null : leasePaidThroughDate ?? this.leasePaidThroughDate,
      frequencyMonths: frequencyMonths ?? this.frequencyMonths,
    );
  }

  factory Flat.fromJson(Map<String, dynamic> json) {
    return Flat(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      // Older builds stored the registration date under `contractDate`.
      registeredDate:
          (json['registeredDate'] ?? json['contractDate']) == null
              ? null
              : DateTime.parse(
                  (json['registeredDate'] ?? json['contractDate']) as String,
                ),
      contractPerson: json['contractPerson'] as String?,
      yearlyRent: (json['yearlyRent'] as num?)?.toDouble(),
      archived: (json['archived'] as bool?) ?? false,
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
      leasePaidThroughDate: json['leasePaidThroughDate'] == null
          ? null
          : DateTime.parse(json['leasePaidThroughDate'] as String),
      frequencyMonths: (json['frequencyMonths'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'registeredDate': registeredDate?.toIso8601String(),
      'contractPerson': contractPerson,
      'yearlyRent': yearlyRent,
      'archived': archived,
      'archivedAt': archivedAt?.toIso8601String(),
      'leasePaidThroughDate': leasePaidThroughDate?.toIso8601String(),
      'frequencyMonths': frequencyMonths,
    };
  }
}
