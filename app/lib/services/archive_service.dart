import '../models/bed.dart';
import '../models/person.dart';

/// Auto-archive rule: a tenant is archived when their `vacatedDate` has
/// passed and no renewal was recorded on or after that date — i.e. they
/// let the stay lapse instead of renewing in time.
///
/// Pure computation over in-memory data; the caller persists the returned
/// lists via [JsonStore].
abstract final class ArchiveService {
  /// Whether [person] qualifies for archiving as of [today]. Already-archived
  /// people never qualify again (idempotent sweeps).
  static bool shouldArchive(Person person, DateTime today) {
    final vacated = person.vacatedDate;
    if (vacated == null || person.archived) return false;
    if (!vacated.isBefore(today)) return false;
    // Only the most recent renewal counts — a renewal from an earlier stay
    // does not rescue a later lapsed cycle.
    if (person.renewalHistory.isEmpty) return true;
    return person.renewalHistory.last.isBefore(vacated);
  }

  /// Archives every qualifying person and frees their beds. Returns new
  /// lists; input lists are not mutated. Unrelated people/beds come back
  /// untouched (same instances). The archived person keeps `bedId`/`flatId`
  /// so the Archive screen can show their former flat and bed.
  static (List<Person>, List<Bed>) checkAndArchive(
    List<Person> persons,
    List<Bed> beds,
    DateTime today,
  ) {
    final people = List<Person>.of(persons);
    final updatedBeds = List<Bed>.of(beds);
    final freedBedIds = <String>{};

    for (var i = 0; i < people.length; i++) {
      final person = people[i];
      if (!shouldArchive(person, today)) continue;
      people[i] = person.copyWith(archived: true, archivedAt: today);
      final bedId = person.bedId;
      if (bedId != null) freedBedIds.add(bedId);
    }

    if (freedBedIds.isNotEmpty) {
      for (var i = 0; i < updatedBeds.length; i++) {
        final bed = updatedBeds[i];
        if (bed.tenantId != null && freedBedIds.contains(bed.id)) {
          updatedBeds[i] = bed.copyWith(clearTenantId: true);
        }
      }
    }

    return (people, updatedBeds);
  }
}
