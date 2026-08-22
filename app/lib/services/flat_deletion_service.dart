import '../models/expense.dart';
import '../models/flat.dart';
import '../models/lease_cheque_record.dart';
import '../models/payment.dart';

/// Outcome of a delete request on a flat.
enum FlatDeleteOutcome { hardDelete, archive }

/// What will happen to a flat if it is deleted right now, plus the data the
/// caller needs to act on it. Pure logic — no I/O.
class FlatDeleteDecision {
  const FlatDeleteDecision._(this.outcome);

  const FlatDeleteDecision.hardDelete() : this._(FlatDeleteOutcome.hardDelete);
  const FlatDeleteDecision.archive() : this._(FlatDeleteOutcome.archive);

  final FlatDeleteOutcome outcome;

  bool get isHardDelete => outcome == FlatDeleteOutcome.hardDelete;
  bool get isArchive => outcome == FlatDeleteOutcome.archive;

  /// Plain-language copy for the confirm dialog.
  String get confirmMessage => isHardDelete
      ? 'This flat has no financial history and will be permanently deleted.'
      : 'This flat has payment history and will be archived, not deleted.';
}

/// Decides whether a flat can be hard-deleted or must only be archived.
/// A flat with ANY financial history — expenses, lease cheque payments, or
/// tenant payments (via its beds/tenants) — is preserved as an archived
/// record; history-free flats are removed without a trace.
abstract final class FlatDeletionService {
  /// Whether [flatId] is referenced by any Expense, LeaseChequeRecord or
  /// Payment record.
  static bool hasFinancialHistory({
    required String flatId,
    required List<Expense> expenses,
    required List<LeaseChequeRecord> leaseChequeRecords,
    required List<Payment> payments,
  }) {
    final expenseHit = expenses.any((e) => e.flatId == flatId);
    if (expenseHit) return true;
    final chequeHit = leaseChequeRecords.any((r) => r.flatId == flatId);
    if (chequeHit) return true;
    return payments.any((p) => p.flatId == flatId);
  }

  /// Resolves what "delete" means for [flat] given the financial data.
  static FlatDeleteDecision resolveDelete({
    required Flat flat,
    required List<Expense> expenses,
    required List<LeaseChequeRecord> leaseChequeRecords,
    required List<Payment> payments,
  }) {
    final hasHistory = hasFinancialHistory(
      flatId: flat.id,
      expenses: expenses,
      leaseChequeRecords: leaseChequeRecords,
      payments: payments,
    );
    return hasHistory
        ? const FlatDeleteDecision.archive()
        : const FlatDeleteDecision.hardDelete();
  }
}
