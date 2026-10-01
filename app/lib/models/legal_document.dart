import '../utils/ids.dart';

/// A scanned piece of paperwork attached to a flat — lease contract, utility
/// registration, inspection report, etc.
///
/// The document is metadata plus a path to an image that lives **inside the
/// app's documents directory** (copied at pick time). The transient path
/// handed back by the OS image picker is never persisted, so the thumbnail
/// keeps resolving across reboots and app updates.
class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.flatId,
    required this.label,
    required this.imagePath,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String flatId;

  /// Short human name, e.g. "Lease Contract 2026". Required — a document with
  /// no name is impossible to pick out of a grid.
  final String label;

  /// Free-form note. Optional.
  final String? description;

  /// Path to the image inside the app documents directory, e.g.
  /// `<appDocs>/LUCKY/legal_docs/1234.jpg`. Never a picker cache path.
  final String imagePath;

  final DateTime createdAt;

  LegalDocument copyWith({
    String? id,
    String? flatId,
    String? label,
    String? description,
    String? imagePath,
    DateTime? createdAt,
    bool clearDescription = false,
  }) {
    return LegalDocument(
      id: id ?? this.id,
      flatId: flatId ?? this.flatId,
      label: label ?? this.label,
      description: clearDescription ? null : description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory LegalDocument.fromJson(Map<String, dynamic> json) {
    return LegalDocument(
      id: json['id'] as String,
      flatId: json['flatId'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      imagePath: json['imagePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flatId': flatId,
      'label': label,
      'description': description,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Builds a brand new document with a generated id and the current time.
  /// Used by the add flow so no screen has to remember to set either field.
  static LegalDocument createNew({
    required String flatId,
    required String label,
    String? description,
    required String imagePath,
  }) {
    return LegalDocument(
      id: newId(),
      flatId: flatId,
      label: label,
      description: description,
      imagePath: imagePath,
      createdAt: DateTime.now(),
    );
  }
}
