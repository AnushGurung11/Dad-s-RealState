import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/lease_cheque_setting.dart';
import '../utils/format.dart';

/// Abstraction over the notification platform so logic can be unit-tested
/// without touching platform channels.
abstract class NotificationScheduler {
  Future<void> scheduleAt({
    required DateTime when,
    required int id,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);
}

/// [NotificationScheduler] backed by [flutter_local_notifications].
class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'lease_checks',
    'Lease cheques',
    channelDescription: 'Reminders to pay the flat lease cheque to its owner.',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  @override
  Future<void> scheduleAt({
    required DateTime when,
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(android: _androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

/// Schedules/cancels the 3-days-before-due reminder for a flat's lease cheque.
/// Always cancels first, so calling [syncFor] whenever `nextDueDate` or
/// `notifyEnabled` changes reschedules cleanly.
class NotificationService {
  NotificationService(this._scheduler);

  final NotificationScheduler _scheduler;

  int _idFor(LeaseChequeSetting setting) =>
      setting.id.hashCode & 0x7fffffff;

  /// Cancels any existing reminder for [setting], then schedules a new one
  /// 3 days before `nextDueDate` (at 09:00) when notifications are enabled.
  /// No-op when the reminder date is already in the past.
  Future<void> syncFor(LeaseChequeSetting setting) async {
    final id = _idFor(setting);
    await _scheduler.cancel(id);
    if (!setting.notifyEnabled) return;
    final when = DateTime(
      setting.nextDueDate.year,
      setting.nextDueDate.month,
      setting.nextDueDate.day - 3,
      9,
    );
    if (!when.isAfter(DateTime.now())) return;
    final owner = setting.ownerName.trim().isEmpty
        ? 'Lease cheque'
        : setting.ownerName;
    final date = '${setting.nextDueDate.day}/${setting.nextDueDate.month}';
    await _scheduler.scheduleAt(
      when: when,
      id: id,
      title: 'Lease cheque due $date',
      body: '$owner — ${formatMoneyShort(setting.amount)}',
    );
  }
}

/// One-time plugin setup; call from `main()` before `runApp`.
Future<void> initNotifications(FlutterLocalNotificationsPlugin plugin) async {
  tzdata.initializeTimeZones();
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await plugin.initialize(settings: settings);
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}