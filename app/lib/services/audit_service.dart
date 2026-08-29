import '../models/audit_log_entry.dart';
import '../utils/ids.dart';
import 'json_store.dart';

class AuditService {
  const AuditService(this.store);

  final JsonStore store;

  Future<void> logEdit(
    AuditEntityType entityType,
    String entityId,
    Map<String, dynamic> before,
    Map<String, dynamic> after,
  ) async {
    final entry = AuditLogEntry(
      id: newId(),
      entityType: entityType,
      entityId: entityId,
      action: AuditAction.edit,
      beforeSnapshot: before,
      afterSnapshot: after,
      timestamp: DateTime.now(),
    );
    store.upsertAuditLog(entry);
  }

  Future<void> logDelete(
    AuditEntityType entityType,
    String entityId,
    Map<String, dynamic> before,
  ) async {
    final entry = AuditLogEntry(
      id: newId(),
      entityType: entityType,
      entityId: entityId,
      action: AuditAction.delete,
      beforeSnapshot: before,
      afterSnapshot: null,
      timestamp: DateTime.now(),
    );
    store.upsertAuditLog(entry);
  }
}
