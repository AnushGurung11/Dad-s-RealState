class Person {
  const Person({
    required this.id,
    required this.name,
    required this.contact,
    this.workplaceOrInfo,
    this.bedId,
    this.flatId,
    this.joinDate,
    this.plannedStayMonths,
    this.vacatedDate,
    this.depositAmount,
    this.monthlyRent,
    this.others,
    this.renewalHistory = const [],
  });

  final String id;
  final String name;
  final String contact;
  final String? workplaceOrInfo;
  final String? bedId;

  /// Denormalized from the assigned bed so screens can group tenants by flat
  /// without joining through the bed collection. Kept in sync at assign/
  /// unassign time.
  final String? flatId;

  /// Date the tenant joined a bed. Captured at assignment.
  final DateTime? joinDate;

  /// Months the tenant stated they would stay. Captured at assignment,
  /// extended via renewals.
  final int? plannedStayMonths;

  /// Actual move-out date. Auto-computed at assignment as
  /// joinDate + plannedStayMonths, editable later to reflect reality.
  final DateTime? vacatedDate;

  /// Deposit collected at assignment. Counts as income.
  final double? depositAmount;

  /// The tenant's own rent. Defaults from the bed's default rent at
  /// assignment, editable per-person.
  final double? monthlyRent;

  /// Free-text notes about the tenant.
  final String? others;

  /// Timestamp of every renewal. Lets the archive logic (chunk 4) tell an
  /// abandoned tenant apart from an actively renewed one.
  final List<DateTime> renewalHistory;

  Person copyWith({
    String? id,
    String? name,
    String? contact,
    String? workplaceOrInfo,
    String? bedId,
    String? flatId,
    DateTime? joinDate,
    int? plannedStayMonths,
    DateTime? vacatedDate,
    double? depositAmount,
    double? monthlyRent,
    String? others,
    List<DateTime>? renewalHistory,
    bool clearBedId = false,
    bool clearFlatId = false,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      workplaceOrInfo: workplaceOrInfo ?? this.workplaceOrInfo,
      bedId: clearBedId ? null : bedId ?? this.bedId,
      flatId: clearFlatId ? null : flatId ?? this.flatId,
      joinDate: joinDate ?? this.joinDate,
      plannedStayMonths: plannedStayMonths ?? this.plannedStayMonths,
      vacatedDate: vacatedDate ?? this.vacatedDate,
      depositAmount: depositAmount ?? this.depositAmount,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      others: others ?? this.others,
      renewalHistory: renewalHistory ?? this.renewalHistory,
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
      flatId: json['flatId'] as String?,
      joinDate: json['joinDate'] == null
          ? null
          : DateTime.parse(json['joinDate'] as String),
      plannedStayMonths: json['plannedStayMonths'] as int?,
      // Older builds stored the vacated date under `leaveDate`.
      vacatedDate: (json['vacatedDate'] ?? json['leaveDate']) == null
          ? null
          : DateTime.parse(
              (json['vacatedDate'] ?? json['leaveDate']) as String,
            ),
      depositAmount: (json['depositAmount'] as num?)?.toDouble(),
      monthlyRent: (json['monthlyRent'] as num?)?.toDouble(),
      others: json['others'] as String?,
      renewalHistory: ((json['renewalHistory'] as List?) ?? const [])
          .map((item) => DateTime.parse(item as String))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contact': contact,
      'workplaceOrInfo': workplaceOrInfo,
      'bedId': bedId,
      'flatId': flatId,
      'joinDate': joinDate?.toIso8601String(),
      'plannedStayMonths': plannedStayMonths,
      'vacatedDate': vacatedDate?.toIso8601String(),
      'depositAmount': depositAmount,
      'monthlyRent': monthlyRent,
      'others': others,
      'renewalHistory': renewalHistory.map((d) => d.toIso8601String()).toList(),
    };
  }
}