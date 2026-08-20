import 'package:flutter/material.dart';

/// App-wide accent color — a deep teal distinct from generic Material blue.
const Color appAccent = Color(0xFF0F766E);

/// Status colors surfaced to widgets via [AppStatusColors]; widgets must pull
/// colors from the extension instead of hardcoding hex values.
const AppStatusColors appStatusColors = AppStatusColors(
  success: Color(0xFF16A34A),
  warning: Color(0xFFD97706),
  danger: Color(0xFFDC2626),
  neutral: Color(0xFF6B7280),
);

/// Theme extension exposing status colors (success/warning/danger/neutral).
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.neutral,
  });

  final Color success;
  final Color warning;
  final Color danger;
  final Color neutral;

  @override
  AppStatusColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? neutral,
  }) {
    return AppStatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  AppStatusColors lerp(AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

/// Builds light or dark [ThemeData] from the teal seed with the status color
/// extension attached.
ThemeData buildAppTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: appAccent,
    brightness: brightness,
  );
  final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
  return base.copyWith(extensions: [appStatusColors]);
}

/// Light theme for [ThemeMode.light] and tests.
final ThemeData appLightTheme = buildAppTheme(Brightness.light);

/// Dark theme for [ThemeMode.dark].
final ThemeData appDarkTheme = buildAppTheme(Brightness.dark);