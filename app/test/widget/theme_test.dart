import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  test('light ThemeData builds without error', () {
    expect(appLightTheme.brightness, Brightness.light);
    expect(appLightTheme.colorScheme, isA<ColorScheme>());
  });

  test('AppStatusColors resolves under light theme with distinct status hues', () {
    final colors = appLightTheme.extension<AppStatusColors>();
    expect(colors, isNotNull);
    expect(colors!.success, isNot(colors.warning));
    expect(colors.warning, isNot(colors.danger));
    expect(colors.danger, isNot(colors.neutral));
    expect(colors.neutral, isNot(colors.success));
  });

  testWidgets('extension is reachable via Theme.of under light theme',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
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
  });
}
