import 'package:flutter/material.dart';

// ---- Spec Color Tokens ----
const Color appBg = Color(0xFF09090B);
const Color appSurface1 = Color(0xFF111115);
const Color appSurface2 = Color(0xFF18181D);
const Color appSurface3 = Color(0xFF222229);

const Color appBorder = Color(0x12FFFFFF); // rgba(255,255,255,0.07)
const Color appBorderMd = Color(0x1CFFFFFF); // rgba(255,255,255,0.11)

const Color appText1 = Color(0xFFF5F5F7);
const Color appText2 = Color(0xFF8E8E99);
const Color appText3 = Color(0xFF48484F);
const Color appText4 = Color(0xFF2C2C32);

/// Complementary accent pair — blue primary, amber complementary.
const Color appAccent = Color(0xFF4F80E1);
const Color appAccentDim = Color(0x244F80E1); // rgba(79,128,225,0.14)
const Color appAccentTxt = Color(0xFFA8C0F8);
const Color appComp = Color(0xFFE18A4F);
const Color appCompDim = Color(0x24E18A4F); // rgba(225,138,79,0.14)

/// Semantic colors — iOS palette.
const Color appSuccess = Color(0xFF34C759);
const Color appSuccessDim = Color(0x1F34C759); // 12%
const Color appSuccessBorder = Color(0x2E34C759); // 18%
const Color appDanger = Color(0xFFFF453A);
const Color appDangerDim = Color(0x1FFF453A);
const Color appDangerBorder = Color(0x2EFF453A);
const Color appWarn = Color(0xFFFF9F0A);
const Color appWarnDim = Color(0x1FFF9F0A);
const Color appWarnBorder = Color(0x2EFF9F0A);

/// Legacy alias — tests expect `appAccent = #4F80E1` after migration.
const Color appPrimary = appAccent;

/// Golden ratio scale kept for backward-compat but spec uses dedicated sizes.
/// We keep class for existing imports but values now reflect spec (10/12/15/17/34).
class AppTextScale {
  const AppTextScale._();

  // Spec scale mapping to legacy names:
  // caption -> 10-11 uppercase labels / 12 caption (we expose 11 as caption)
  // body    -> 15 body
  // subtitle-> 17 AppBar
  // title   -> 34 stat/hero
  static const double caption = 10.0; // labelSmall uppercase
  static const double body = 15.0;
  static const double subtitle = 17.0;
  static const double title = 34.0;

  static TextTheme apply(TextTheme base) {
    return base.copyWith(
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8, // 0.08em at 10px
      ),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w400),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w400),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w400),
      titleSmall: base.titleSmall?.copyWith(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleMedium: base.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3),
      titleLarge: base.titleLarge?.copyWith(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -1),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -1),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -0.5),
      displaySmall: base.displaySmall?.copyWith(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -1),
    );
  }
}

/// Status colors — iOS palette per spec.
const AppStatusColors appStatusColors = AppStatusColors(
  success: appSuccess,
  warning: appWarn,
  danger: appDanger,
  neutral: appText3, // #48484F
);

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

  Color get successDim => success.withValues(alpha: 0.12);
  Color get warningDim => warning.withValues(alpha: 0.12);
  Color get dangerDim => danger.withValues(alpha: 0.12);
  Color get successBorder => success.withValues(alpha: 0.18);
  Color get warningBorder => warning.withValues(alpha: 0.18);
  Color get dangerBorder => danger.withValues(alpha: 0.18);

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

ThemeData buildAppTheme(Brightness brightness) {
  // Spec is dark-first; light theme uses same dark surfaces for consistency
  // but with dark ColorScheme so text remains correct.
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.dark(
    primary: appAccent,
    onPrimary: appText1,
    secondary: appComp,
    onSecondary: appText1,
    surface: appSurface1,
    onSurface: appText1,
    surfaceContainerHighest: appSurface2,
    onSurfaceVariant: appText2,
    outline: appBorder,
    outlineVariant: appBorderMd,
    error: appDanger,
    onError: appText1,
    primaryContainer: appAccentDim,
    secondaryContainer: appCompDim,
    errorContainer: appDangerDim,
  );

  final base = ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: appBg,
    useMaterial3: true,
    fontFamily: null, // system font stack; Flutter falls back to platform
  );

  final textTheme = AppTextScale.apply(base.textTheme).apply(
        bodyColor: appText1,
        displayColor: appText1,
      );

  return base.copyWith(
    extensions: [appStatusColors],
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xEB09090B), // rgba(9,9,11,0.92) approx
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 52,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: appText1,
      ),
      iconTheme: const IconThemeData(color: appAccent, size: 20),
      shape: const Border(bottom: BorderSide(color: appBorder, width: 1)),
    ),
    cardTheme: const CardThemeData(
      color: appSurface1,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: appBorder, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: appSurface3,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: appBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: appBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x804F80E1), width: 1.5),
      ),
      labelStyle: const TextStyle(fontSize: 15, color: appText2),
      hintStyle: const TextStyle(fontSize: 15, color: appText3),
      floatingLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: appAccent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xF509090B), // rgba(9,9,11,0.96)
      indicatorColor: appAccentDim,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: appAccent);
        }
        return const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: appText3);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: appAccent, size: 22);
        }
        return const IconThemeData(color: appText3, size: 22);
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: appSurface1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: appBorderMd, width: 1),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: appSurface1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: appText1),
      contentTextStyle: TextStyle(fontSize: 15, color: appText1),
    ),
    dividerTheme: const DividerThemeData(color: appBorder, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: appSurface2,
      selectedColor: appAccentDim,
      labelStyle: const TextStyle(fontSize: 12, color: appText2),
      secondaryLabelStyle: const TextStyle(fontSize: 12, color: appAccentTxt),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999), side: const BorderSide(color: appBorder)),
      side: const BorderSide(color: appBorder),
    ),
  );
}

final ThemeData appLightTheme = buildAppTheme(Brightness.dark);
final ThemeData appDarkTheme = buildAppTheme(Brightness.dark);
