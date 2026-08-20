import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/main.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/notification_service.dart';
import 'package:renttrack/services/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps [tester] to pump the app with an injectable in-memory store and mocked
/// shared preferences.
Future<void> pumpApp(
  WidgetTester tester, {
  JsonStore? store,
  Map<String, Object> prefs = const {},
  NotificationService? notifications,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  await tester.pumpWidget(
    RentTrackApp(
      store: store ?? InMemoryJsonStore(),
      prefs: Prefs(await SharedPreferences.getInstance()),
      notifications:
          notifications ?? NotificationService(FakeNotificationScheduler()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps the bottom navigation destination with the given [label].
Future<void> tapNavTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  ));
  await tester.pumpAndSettle();
}

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