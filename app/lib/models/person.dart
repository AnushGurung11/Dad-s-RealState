class Person {
  const Person({
    required this.id,
    required this.name,
    required this.contact,
    this.workplaceOrInfo,
    this.bedId,
    this.joinDate,
    this.plannedStayMonths,
    this.leaveDate,
    this.depositAmount,
  });

  final String id;
  final String name;
  final String contact;
  final String? workplaceOrInfo;
  final String? bedId;

  /// Date the tenant joined a bed. Captured at assignment.
  final DateTime? joinDate;

  /// Months the tenant stated they would stay. Captured at assignment.
  final int? plannedStayMonths;

  /// Expected move-out date. Auto-computed at assignment as
  /// joinDate + plannedStayMonths, editable later to reflect the actual
  /// move-out date.
  final DateTime? leaveDate;

  /// Deposit collected at assignment. Counts as income.
  final double? depositAmount;

  Person copyWith({
    String? id,
    String? name,
    String? contact,
    String? workplaceOrInfo,
    String? bedId,
    DateTime? joinDate,
    int? plannedStayMonths,
    DateTime? leaveDate,
    double? depositAmount,
    bool clearBedId = false,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      workplaceOrInfo: workplaceOrInfo ?? this.workplaceOrInfo,
      bedId: clearBedId ? null : bedId ?? this.bedId,
      joinDate: joinDate ?? this.joinDate,
      plannedStayMonths: plannedStayMonths ?? this.plannedStayMonths,
      leaveDate: leaveDate ?? this.leaveDate,
      depositAmount: depositAmount ?? this.depositAmount,
    );
  }

  bool get hasBed => bedId != null;

  bool get isActiveTenant =>
      bedId != null && joinDate != null && plannedStayMonths != null;

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      name: json['name'] as String,
      contact: json['contact'] as String,
      workplaceOrInfo: json['workplaceOrInfo'] as String?,
      bedId: json['bedId'] as String?,
      joinDate: json['joinDate'] == null
          ? null
          : DateTime.parse(json['joinDate'] as String),
      plannedStayMonths: json['plannedStayMonths'] as int?,
      leaveDate: json['leaveDate'] == null
          ? null
          : DateTime.parse(json['leaveDate'] as String),
      depositAmount: (json['depositAmount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contact': contact,
      'workplaceOrInfo': workplaceOrInfo,
      'bedId': bedId,
      'joinDate': joinDate?.toIso8601String(),
      'plannedStayMonths': plannedStayMonths,
      'leaveDate': leaveDate?.toIso8601String(),
      'depositAmount': depositAmount,
    };
  }
}