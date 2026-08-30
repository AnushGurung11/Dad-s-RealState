import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  test('light and dark ThemeData both build without error', () {
    // Spec is dark-first: both themes use dark surfaces (#09090B)
    expect(appLightTheme.brightness, Brightness.dark);
    expect(appDarkTheme.brightness, Brightness.dark);
    expect(appLightTheme.colorScheme, isA<ColorScheme>());
    expect(appDarkTheme.colorScheme, isA<ColorScheme>());
  });

  test('AppStatusColors resolves under both themes with distinct status hues',
      () {
    for (final theme in [appLightTheme, appDarkTheme]) {
      final colors = theme.extension<AppStatusColors>();
      expect(colors, isNotNull);
      expect(colors!.success, isNot(colors.warning));
      expect(colors.warning, isNot(colors.danger));
      expect(colors.danger, isNot(colors.neutral));
      expect(colors.neutral, isNot(colors.success));
    }
  });

  testWidgets('extension is reachable via Theme.of under both themes',
      (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme =
          brightness == Brightness.light ? appLightTheme : appDarkTheme;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              final colors =
                  Theme.of(context).extension<AppStatusColors>();
              return Text(colors != null ? 'resolved' : 'missing');
            },
          ),
        ),
      );
      expect(find.text('resolved'), findsOneWidget);
    }
  });
}