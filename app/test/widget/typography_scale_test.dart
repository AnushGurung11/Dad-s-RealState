import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  test('TextTheme sizes reflect the defined golden-ratio steps', () {
    final lightTheme = appLightTheme;
    final textTheme = lightTheme.textTheme;

    // Verify the golden ratio scale is applied
    // caption ≈ 9sp
    expect(textTheme.labelSmall?.fontSize, 9.0);
    expect(textTheme.bodySmall?.fontSize, 9.0);

    // body = 14sp
    expect(textTheme.bodyMedium?.fontSize, 14.0);
    expect(textTheme.bodyLarge?.fontSize, 14.0);

    // subtitle ≈ 23sp
    expect(textTheme.titleSmall?.fontSize, 23.0);
    expect(textTheme.titleMedium?.fontSize, 23.0);

    // title ≈ 37sp
    expect(textTheme.titleLarge?.fontSize, 37.0);
    expect(textTheme.headlineSmall?.fontSize, 37.0);
    expect(textTheme.headlineMedium?.fontSize, 37.0);
    expect(textTheme.displaySmall?.fontSize, 37.0);
  });

  test('Dark theme also has the golden-ratio text scale', () {
    final darkTheme = appDarkTheme;
    final textTheme = darkTheme.textTheme;

    expect(textTheme.labelSmall?.fontSize, 9.0);
    expect(textTheme.bodySmall?.fontSize, 9.0);
    expect(textTheme.bodyMedium?.fontSize, 14.0);
    expect(textTheme.bodyLarge?.fontSize, 14.0);
    expect(textTheme.titleSmall?.fontSize, 23.0);
    expect(textTheme.titleMedium?.fontSize, 23.0);
    expect(textTheme.titleLarge?.fontSize, 37.0);
  });

  test('AppStatusColors extension is attached to theme', () {
    final lightTheme = appLightTheme;
    final statusColors = lightTheme.extension<AppStatusColors>();
    expect(statusColors, isNotNull);
    expect(statusColors!.success, const Color(0xFF16A34A));
    expect(statusColors.warning, const Color(0xFFD97706));
    expect(statusColors.danger, const Color(0xFFDC2626));
    expect(statusColors.neutral, const Color(0xFF6B7280));
  });
}