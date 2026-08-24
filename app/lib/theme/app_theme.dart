import 'package:flutter/material.dart';

/// App-wide accent color — a deep teal distinct from generic Material blue.
const Color appAccent = Color(0xFF0F766E);

/// Golden ratio constant (~1.618)
const double _phi = 1.618;

/// Base body size in sp
const double _baseBodySize = 14.0;

/// Golden ratio type scale
/// Each step relates to the next by the golden ratio (~1.618)
/// caption ≈ base / φ       (~8.7sp → 9sp)
/// body   = base            (14sp)
/// subtitle ≈ base × φ      (~22.6sp → 23sp)
/// title  ≈ base × φ²       (~36.7sp → 37sp)
class AppTextScale {
  const AppTextScale._();
  
  static const double caption = 9.0;
  static const double body = _baseBodySize;
  static const double subtitle = 23.0;
  static const double title = 37.0;
  
  /// Creates a TextTheme with the golden ratio scale applied
  static TextTheme apply(TextTheme base) {
    return base.copyWith(
      labelSmall: base.labelSmall?.copyWith(fontSize: caption),
      bodySmall: base.bodySmall?.copyWith(fontSize: caption),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: body),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: body),
      titleSmall: base.titleSmall?.copyWith(fontSize: subtitle),
      titleMedium: base.titleMedium?.copyWith(fontSize: subtitle),
      titleLarge: base.titleLarge?.copyWith(fontSize: title),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: title),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: title),
      displaySmall: base.displaySmall?.copyWith(fontSize: title),
    );
  }
}

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
  return base.copyWith(
    extensions: [appStatusColors],
    textTheme: AppTextScale.apply(base.textTheme),
  );
}

/// Light theme for [ThemeMode.light] and tests.
final ThemeData appLightTheme = buildAppTheme(Brightness.light);

/// Dark theme for [ThemeMode.dark].
final ThemeData appDarkTheme = buildAppTheme(Brightness.dark);