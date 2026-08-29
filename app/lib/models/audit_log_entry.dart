enum AuditEntityType { payment, expense, leaseChequeRecord }

enum AuditAction { edit, delete }

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.beforeSnapshot,
    this.afterSnapshot,
    required this.timestamp,
  });

  final String id;
  final AuditEntityType entityType;
  final String entityId;
  final AuditAction action;
  final Map<String, dynamic> beforeSnapshot;
  final Map<String, dynamic>? afterSnapshot;
  final DateTime timestamp;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'] as String,
      entityType: AuditEntityType.values.firstWhere(
        (e) => e.name == json['entityType'],
        orElse: () => AuditEntityType.payment,
      ),
      entityId: json['entityId'] as String,
      action: AuditAction.values.firstWhere(
        (a) => a.name == json['action'],
        orElse: () => AuditAction.edit,
      ),
      beforeSnapshot: (json['beforeSnapshot'] as Map).cast<String, dynamic>(),
      afterSnapshot: (json['afterSnapshot'] as Map?)?.cast<String, dynamic>(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType.name,
      'entityId': entityId,
      'action': action.name,
      'beforeSnapshot': beforeSnapshot,
      'afterSnapshot': afterSnapshot,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
