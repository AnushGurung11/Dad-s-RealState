import '../models/audit_log_entry.dart';
import 'audit_service.dart';
import 'json_store.dart';

/// One shared service used by every edit/delete entry point.
/// Handles audit logging before applying changes.
class TransactionEditService {
  TransactionEditService(this.store) : _audit = AuditService(store);

  final JsonStore store;
  final AuditService _audit;

  // ── Payment ────────────────────────────────────────────────────────

  Future<void> editPayment(
    String id, {
    double? amount,
    String? month,
    DateTime? date,
    String? description,
    String? paymentMethod,
    // Protected fields - if provided, they are ignored (no-op)
    String? personId,
    String? bedId,
    String? flatId,
    String? type,
  }) async {
    final idx = store.payments.indexWhere((p) => p.id == id);
    if (idx == -1) throw StateError('Payment $id not found');
    final before = store.payments[idx];
    // Only allowed fields are updated; protected fields are ignored
    final updated = before.copyWith(
      amountPaid: amount ?? before.amountPaid,
      month: month ?? (date != null ? '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}' : before.month),
      description: description ?? before.description,
      paymentMethod: paymentMethod ?? before.paymentMethod,
    );
    await _audit.logEdit(
      AuditEntityType.payment,
      id,
      before.toJson(),
      updated.toJson(),
    );
    store.upsertPayment(updated);
  }

  Future<void> deletePayment(String id) async {
    final idx = store.payments.indexWhere((p) => p.id == id);
    if (idx == -1) throw StateError('Payment $id not found');
    final before = store.payments[idx];
    await _audit.logDelete(
      AuditEntityType.payment,
      id,
      before.toJson(),
    );
    store.deletePayment(id);
  }

  // ── Expense ────────────────────────────────────────────────────────

  Future<void> editExpense(
    String id, {
    double? amount,
    DateTime? date,
    String? description,
    String? paymentMethod,
    // Protected
    String? flatId,
    String? category,
  }) async {
    final idx = store.expenses.indexWhere((e) => e.id == id);
    if (idx == -1) throw StateError('Expense $id not found');
    final before = store.expenses[idx];
    final after = before.copyWith(
      amount: amount ?? before.amount,
      date: date ?? before.date,
      description: description ?? before.effectiveDescription,
      paymentMethod: paymentMethod ?? before.paymentMethod,
    );
    await _audit.logEdit(
      AuditEntityType.expense,
      id,
      before.toJson(),
      after.toJson(),
    );
    store.upsertExpense(after);
  }

  Future<void> deleteExpense(String id) async {
    final idx = store.expenses.indexWhere((e) => e.id == id);
    if (idx == -1) throw StateError('Expense $id not found');
    final before = store.expenses[idx];
    await _audit.logDelete(
      AuditEntityType.expense,
      id,
      before.toJson(),
    );
    store.deleteExpense(id);
  }

  // ── LeaseChequeRecord ──────────────────────────────────────────────

  Future<void> editLeaseChequeRecord(
    String id, {
    double? amount,
    DateTime? paidDate,
    DateTime? dueDate,
    DateTime? date,
    String? description,
    String? paymentMethod,
    // Protected
    String? flatId,
  }) async {
    final idx = store.leaseChequeRecords.indexWhere((r) => r.id == id);
    if (idx == -1) throw StateError('LeaseChequeRecord $id not found');
    final before = store.leaseChequeRecords[idx];
    final after = before.copyWith(
      amount: amount ?? before.amount,
      paidDate: paidDate ?? date ?? before.paidDate,
      dueDate: dueDate ?? before.dueDate,
      description: description ?? before.description,
      paymentMethod: paymentMethod ?? before.paymentMethod,
    );
    await _audit.logEdit(
      AuditEntityType.leaseChequeRecord,
      id,
      before.toJson(),
      after.toJson(),
    );
    store.upsertChequeRecord(after);
    // Deliberately do NOT update LeaseChequeSetting.nextDueDate
  }

  Future<void> deleteLeaseChequeRecord(String id) async {
    final idx = store.leaseChequeRecords.indexWhere((r) => r.id == id);
    if (idx == -1) throw StateError('LeaseChequeRecord $id not found');
    final before = store.leaseChequeRecords[idx];
    await _audit.logDelete(
      AuditEntityType.leaseChequeRecord,
      id,
      before.toJson(),
    );
    store.deleteChequeRecord(id);
    // Deliberately do NOT alter LeaseChequeSetting.nextDueDate
  }
}
