import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/lease_cheque_setting.dart';
import 'package:renttrack/services/notification_service.dart';

/// Records scheduling calls instead of touching platform channels.
class FakeNotificationScheduler implements NotificationScheduler {
  final List<({DateTime when, int id, String title, String body})> scheduled =
      [];
  final List<int> cancelled = [];

  @override
  Future<void> scheduleAt({
    required DateTime when,
    required int id,
    required String title,
    required String body,
  }) async {
    scheduled.add((when: when, id: id, title: title, body: body));
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }
}

void main() {
  LeaseChequeSetting setting({
    String id = 's1',
    String ownerName = 'Owner',
    double amount = 4000,
    DateTime? nextDueDate,
    bool notifyEnabled = true,
  }) {
    return LeaseChequeSetting(
      id: id,
      flatId: 'f1',
      ownerName: ownerName,
      amount: amount,
      nextDueDate: nextDueDate ?? DateTime(2026, 8, 25),
      notifyEnabled: notifyEnabled,
    );
  }

  group('NotificationService', () {
    test('schedules a notification exactly 3 days before nextDueDate', () async {
      final fake = FakeNotificationScheduler();
      final service = NotificationService(fake);
      await service.syncFor(setting(nextDueDate: DateTime(2026, 8, 25)));
      expect(fake.scheduled, hasLength(1));
      final s = fake.scheduled.single;
      expect(s.when, DateTime(2026, 8, 22, 9));
      expect(s.body, 'Owner — AED 4000');
    });

    test('does not schedule when notifyEnabled is false', () async {
      final fake = FakeNotificationScheduler();
      final service = NotificationService(fake);
      await service.syncFor(setting(notifyEnabled: false));
      expect(fake.scheduled, isEmpty);
      expect(fake.cancelled, hasLength(1));
    });

    test('reschedules (cancels old, creates new) when nextDueDate changes',
        () async {
      final fake = FakeNotificationScheduler();
      final service = NotificationService(fake);
      await service.syncFor(setting(nextDueDate: DateTime(2026, 8, 25)));
      await service.syncFor(setting(nextDueDate: DateTime(2026, 10, 25)));
      expect(fake.cancelled, hasLength(2));
      expect(fake.scheduled, hasLength(2));
      expect(fake.scheduled.last.when, DateTime(2026, 10, 22, 9));
    });

    test('does not schedule when the reminder date is already past',
        () async {
      final fake = FakeNotificationScheduler();
      final service = NotificationService(fake);
      await service.syncFor(setting(nextDueDate: DateTime(2020, 1, 1)));
      expect(fake.scheduled, isEmpty);
    });
  });
}