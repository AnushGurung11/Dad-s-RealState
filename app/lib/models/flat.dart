class Flat {
  const Flat({
    required this.id,
    required this.name,
    required this.address,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String address;
  final DateTime createdAt;

  Flat copyWith({String? id, String? name, String? address, DateTime? createdAt}) {
    return Flat(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Flat.fromJson(Map<String, dynamic> json) {
    return Flat(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}