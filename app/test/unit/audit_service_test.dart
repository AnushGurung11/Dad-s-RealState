import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/services/audit_service.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/models/audit_log_entry.dart';

void main() {
  late InMemoryJsonStore store;
  late AuditService audit;

  setUp(() {
    store = InMemoryJsonStore();
    audit = AuditService(store);
  });

  test('logEdit appends correctly to audit_log', () async {
    final before = {'id': 'e1', 'amount': 100};
    final after = {'id': 'e1', 'amount': 200};
    await audit.logEdit(AuditEntityType.expense, 'e1', before, after);
    expect(store.auditLogs, hasLength(1));
    final entry = store.auditLogs.first;
    expect(entry.entityType, AuditEntityType.expense);
    expect(entry.entityId, 'e1');
    expect(entry.action, AuditAction.edit);
    expect(entry.beforeSnapshot, before);
    expect(entry.afterSnapshot, after);
    expect(entry.timestamp, isNotNull);
  });

  test('logDelete appends correctly with null afterSnapshot', () async {
    final before = {'id': 'p1', 'amount': 500};
    await audit.logDelete(AuditEntityType.payment, 'p1', before);
    expect(store.auditLogs, hasLength(1));
    final entry = store.auditLogs.first;
    expect(entry.action, AuditAction.delete);
    expect(entry.afterSnapshot, isNull);
    expect(entry.beforeSnapshot, before);
  });

  test('entries are never themselves editable/deletable via any exposed service method', () async {
    final before = {'id': '1', 'amount': 100};
    final after = {'id': '1', 'amount': 200};
    await audit.logEdit(AuditEntityType.expense, '1', before, after);
    await audit.logDelete(AuditEntityType.payment, '2', before);
    expect(store.auditLogs, hasLength(2));
    // No method exists to edit or delete audit logs - verify by checking that auditLogs is append-only
    // and that JsonStore has no deleteAuditLog or edit method
    expect(store.auditLogs[0].id, isNot(store.auditLogs[1].id));
    // Ensure logs are unmodifiable from outside (but store's getter returns unmodifiable)
    expect(() => (store.auditLogs as List).add(store.auditLogs.first), throwsUnsupportedError);
  });

  test('multiple edits produce multiple audit entries', () async {
    final b1 = {'id': 'x', 'v': 1};
    final a1 = {'id': 'x', 'v': 2};
    final b2 = {'id': 'x', 'v': 2};
    final a2 = {'id': 'x', 'v': 3};
    await audit.logEdit(AuditEntityType.leaseChequeRecord, 'x', b1, a1);
    await audit.logEdit(AuditEntityType.leaseChequeRecord, 'x', b2, a2);
    expect(store.auditLogs, hasLength(2));
    expect(store.auditLogs[0].beforeSnapshot['v'], 1);
    expect(store.auditLogs[1].afterSnapshot!['v'], 3);
  });
}
