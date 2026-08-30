import 'package:flutter/material.dart';

// ---- Spec Color Tokens — Dark (default) ----
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

/// Complementary accent pair — blue primary, amber complementary. (Dark)
const Color appAccent = Color(0xFF4F80E1);
const Color appAccentDim = Color(0x244F80E1); // rgba(79,128,225,0.14)
const Color appAccentTxt = Color(0xFFA8C0F8);
const Color appComp = Color(0xFFE18A4F);
const Color appCompDim = Color(0x24E18A4F); // rgba(225,138,79,0.14)

/// Semantic colors — iOS palette. (Dark)
const Color appSuccess = Color(0xFF34C759);
const Color appSuccessDim = Color(0x1F34C759); // 12%
const Color appSuccessBorder = Color(0x2E34C759); // 18%
const Color appDanger = Color(0xFFFF453A);
const Color appDangerDim = Color(0x1FFF453A);
const Color appDangerBorder = Color(0x2EFF453A);
const Color appWarn = Color(0xFFFF9F0A);
const Color appWarnDim = Color(0x1FFF9F0A);
const Color appWarnBorder = Color(0x2EFF9F0A);

// ---- Light Theme Tokens — per patch.md ----
const Color appLightBg = Color(0xFFF2F2F6);
const Color appLightSurface1 = Color(0xFFE8E8EF);
const Color appLightSurface2 = Color(0xFFFFFFFF);
const Color appLightSurface3 = Color(0xFFEDEDF3);

const Color appLightBorder = Color(0x12000000); // rgba(0,0,0,0.07)
const Color appLightBorderMd = Color(0x1E000000); // rgba(0,0,0,0.12)

const Color appLightText1 = Color(0xFF0C0C12);
const Color appLightText2 = Color(0xFF5C5C6E);
const Color appLightText3 = Color(0xFF9898A8);
const Color appLightText4 = Color(0xFFC4C4D0);

const Color appLightAccent = Color(0xFF3B6FD4);
const Color appLightAccentDim = Color(0x1A3B6FD4); // 0.10
const Color appLightAccentTxt = Color(0xFF2952A3);
const Color appLightComp = Color(0xFFE18A4F);
const Color appLightCompDim = Color(0x1AE18A4F);

const Color appLightSuccess = Color(0xFF1B9E3E);
const Color appLightSuccessDim = Color(0x1F1B9E3E);
const Color appLightSuccessBorder = Color(0x331B9E3E);
const Color appLightDanger = Color(0xFFD93025);
const Color appLightDangerDim = Color(0x1AD93025);
const Color appLightDangerBorder = Color(0x33D93025);
const Color appLightWarn = Color(0xFFD97706);
const Color appLightWarnDim = Color(0x1AD97706);
const Color appLightWarnBorder = Color(0x33D97706);

const Color appLightNavBg = Color(0xF5F2F2F6); // rgba(242,242,246,0.96) -> 0xF5 = 245
const Color appLightAppBarBg = Color(0xEBF2F2F6); // 0.92 -> 235

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

const AppStatusColors appLightStatusColors = AppStatusColors(
  success: appLightSuccess,
  warning: appLightWarn,
  danger: appLightDanger,
  neutral: appLightText3,
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
  final isDark = brightness == Brightness.dark;

  // Pick tokens per brightness
  final bg = isDark ? appBg : appLightBg;
  final surface1 = isDark ? appSurface1 : appLightSurface2;
  final surface2 = isDark ? appSurface2 : appLightSurface1;
  final surface3 = isDark ? appSurface3 : appLightSurface3;
  final border = isDark ? appBorder : appLightBorder;
  final borderMd = isDark ? appBorderMd : appLightBorderMd;
  final text1 = isDark ? appText1 : appLightText1;
  final text2 = isDark ? appText2 : appLightText2;
  final text3 = isDark ? appText3 : appLightText3;
  final accent = isDark ? appAccent : appLightAccent;
  final accentDim = isDark ? appAccentDim : appLightAccentDim;
  final accentTxt = isDark ? appAccentTxt : appLightAccentTxt;
  final comp = isDark ? appComp : appLightComp;
  final compDim = isDark ? appCompDim : appLightCompDim;
  final danger = isDark ? appDanger : appLightDanger;
  final dangerDim = isDark ? appDangerDim : appLightDangerDim;
  final navBg = isDark ? const Color(0xF509090B) : appLightNavBg;
  final appBarBg = isDark ? const Color(0xEB09090B) : appLightAppBarBg;
  final status = isDark ? appStatusColors : appLightStatusColors;
  final focusedBorderColor = isDark ? const Color(0x804F80E1) : const Color(0x803B6FD4);

  final colorScheme = isDark
      ? ColorScheme.dark(
          primary: accent,
          onPrimary: text1,
          secondary: comp,
          onSecondary: text1,
          surface: surface1,
          onSurface: text1,
          surfaceContainerHighest: surface2,
          onSurfaceVariant: text2,
          outline: border,
          outlineVariant: borderMd,
          error: danger,
          onError: text1,
          primaryContainer: accentDim,
          secondaryContainer: compDim,
          errorContainer: dangerDim,
        )
      : ColorScheme.light(
          primary: accent,
          onPrimary: Colors.white,
          secondary: comp,
          onSecondary: Colors.white,
          surface: surface1,
          onSurface: text1,
          surfaceContainerHighest: surface2,
          onSurfaceVariant: text2,
          outline: border,
          outlineVariant: borderMd,
          error: danger,
          onError: Colors.white,
          primaryContainer: accentDim,
          secondaryContainer: compDim,
          errorContainer: dangerDim,
        );

  final base = ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: bg,
    useMaterial3: true,
    fontFamily: null,
  );

  final textTheme = AppTextScale.apply(base.textTheme).apply(
        bodyColor: text1,
        displayColor: text1,
      );

  return base.copyWith(
    extensions: [status],
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 52,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: text1,
      ),
      iconTheme: IconThemeData(color: accent, size: 20),
      shape: Border(bottom: BorderSide(color: border, width: 1)),
    ),
    cardTheme: CardThemeData(
      color: surface1,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface3,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: focusedBorderColor, width: 1.5),
      ),
      labelStyle: TextStyle(fontSize: 15, color: text2),
      hintStyle: TextStyle(fontSize: 15, color: text3),
      floatingLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: accent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: navBg,
      indicatorColor: accentDim,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: accent);
        }
        return TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: text3);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: accent, size: 22);
        }
        return IconThemeData(color: text3, size: 22);
      }),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: borderMd, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface1,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: text1),
      contentTextStyle: TextStyle(fontSize: 15, color: text1),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: surface2,
      selectedColor: accentDim,
      labelStyle: TextStyle(fontSize: 12, color: text2),
      secondaryLabelStyle: TextStyle(fontSize: 12, color: accentTxt),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999), side: BorderSide(color: border)),
      side: BorderSide(color: border),
    ),
  );
}

final ThemeData appLightTheme = buildAppTheme(Brightness.light);
final ThemeData appDarkTheme = buildAppTheme(Brightness.dark);
