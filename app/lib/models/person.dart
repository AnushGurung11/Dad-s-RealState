class Person {
  const Person({
    required this.id,
    required this.name,
    required this.phone,
    this.bedId,
    required this.moveInDate,
  });

  final String id;
  final String name;
  final String phone;
  final String? bedId;
  final DateTime moveInDate;

  Person copyWith({
    String? id,
    String? name,
    String? phone,
    String? bedId,
    DateTime? moveInDate,
    bool clearBedId = false,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      bedId: clearBedId ? null : bedId ?? this.bedId,
      moveInDate: moveInDate ?? this.moveInDate,
    );
  }

  bool get hasBed => bedId != null;

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      bedId: json['bedId'] as String?,
      moveInDate: DateTime.parse(json['moveInDate'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'bedId': bedId,
      'moveInDate': moveInDate.toIso8601String(),
    };
  }
}