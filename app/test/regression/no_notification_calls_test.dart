import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the notification removal: no code path may reference
/// the deleted notification service or its scheduler. Catches stray call
/// sites resurrected by merges or copy-paste.
void main() {
  test('no source file references the removed notification service', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue,
        reason: 'run from the app/ package root');
    final offenders = <String>[];
    final patterns = [
      RegExp(r"notification_service\.dart"),
      RegExp(r'\bNotificationService\b'),
      RegExp(r'\bLocalNotificationScheduler\b'),
      RegExp(r'flutter_local_notifications'),
      RegExp(r'rescheduleAll|syncFor\(|cancelReminderFor\('),
      RegExp(r'initNotifications'),
    ];
    for (final file
        in libDir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final pattern in patterns) {
        if (pattern.hasMatch(source)) {
          offenders.add('${file.path}: ${pattern.pattern}');
          break;
        }
      }
    }
    expect(offenders, isEmpty,
        reason:
            'notifications were fully removed; found references in:\n'
            '${offenders.join('\n')}');
  });

  test('the notification plugin and timezone deps are gone from pubspec',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec.contains('flutter_local_notifications'), isFalse);
    expect(pubspec.contains('timezone'), isFalse);
  });
}
