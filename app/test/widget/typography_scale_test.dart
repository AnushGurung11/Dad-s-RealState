import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  test('TextTheme sizes reflect the spec scale (dark iOS)', () {
    final lightTheme = appLightTheme;
    final textTheme = lightTheme.textTheme;

    // Spec: labels 10 uppercase, caption 12, body 15, AppBar 17, stat 34
    expect(textTheme.labelSmall?.fontSize, 10.0);
    expect(textTheme.bodySmall?.fontSize, 12.0);
    expect(textTheme.bodyMedium?.fontSize, 15.0);
    expect(textTheme.bodyLarge?.fontSize, 15.0);
    expect(textTheme.titleSmall?.fontSize, 17.0);
    expect(textTheme.titleMedium?.fontSize, 17.0);
    expect(textTheme.titleLarge?.fontSize, 34.0);
    expect(textTheme.headlineSmall?.fontSize, 34.0);
    expect(textTheme.headlineMedium?.fontSize, 34.0);
    expect(textTheme.displaySmall?.fontSize, 34.0);
  });

  test('Dark theme also has the spec text scale', () {
    final darkTheme = appDarkTheme;
    final textTheme = darkTheme.textTheme;

    expect(textTheme.labelSmall?.fontSize, 10.0);
    expect(textTheme.bodySmall?.fontSize, 12.0);
    expect(textTheme.bodyMedium?.fontSize, 15.0);
    expect(textTheme.bodyLarge?.fontSize, 15.0);
    expect(textTheme.titleSmall?.fontSize, 17.0);
    expect(textTheme.titleMedium?.fontSize, 17.0);
    expect(textTheme.titleLarge?.fontSize, 34.0);
  });

  test('AppStatusColors extension is attached to theme (iOS palette)', () {
    final lightTheme = appLightTheme;
    final statusColors = lightTheme.extension<AppStatusColors>();
    expect(statusColors, isNotNull);
    expect(statusColors!.success, const Color(0xFF34C759));
    expect(statusColors.warning, const Color(0xFFFF9F0A));
    expect(statusColors.danger, const Color(0xFFFF453A));
    expect(statusColors.neutral, const Color(0xFF48484F));
  });
}