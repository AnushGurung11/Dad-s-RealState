import '../models/person.dart';
import 'json_store.dart';

/// Raised when marking a tenant absconded is not allowed.
class AbscondedException implements Exception {
  const AbscondedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Marks an active tenant as ABSCONDED: a manual, immediate "flag and move
/// on" action, distinct from the stay-expiry auto-archive. Requires a short
/// note ("why/what happened"), frees the bed and preserves every payment
/// record. No refund calculation is attached — that's the early-termination
/// flow, not this.
class AbscondedService {
  const AbscondedService(this.store);

  final JsonStore store;

  Person markAbsconded({
    required String personId,
    required String statusNote,
    DateTime? today,
  }) {
    final note = statusNote.trim();
    if (note.isEmpty) {
      throw const AbscondedException(
          'A short note explaining what happened is required.');
    }
    final person =
        store.people.where((p) => p.id == personId).firstOrNull;
    if (person == null) {
      throw const AbscondedException('Tenant not found.');
    }
    // Guard against double-processing: archived/absconded tenants are
    // already terminal.
    if (person.status != PersonStatus.active) {
      throw const AbscondedException(
          'This tenant has already left — they cannot be marked absconded again.');
    }

    final day = today ?? DateTime.now();
    store.runBatched(() {
      store.upsertPerson(person.copyWith(
        status: PersonStatus.absconded,
        statusDate: day,
        statusNote: note,
      ));
      // Free their bed; all Payment records stay untouched.
      final bed = store.beds
          .where((b) => b.tenantId == person.id)
          .firstOrNull;
      if (bed != null) {
        store.upsertBed(bed.copyWith(clearTenantId: true));
      }
    });
    return person.copyWith(
      status: PersonStatus.absconded,
      statusDate: day,
      statusNote: note,
    );
  }
}
