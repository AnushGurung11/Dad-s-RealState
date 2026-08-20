import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/theme/app_theme.dart';
import 'package:renttrack/widgets/status_badge.dart';

void main() {
  testWidgets('each StatusKind renders with its themed color and label',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: Column(
            children: const [
              StatusBadge(kind: StatusKind.success, label: 'Paid'),
              StatusBadge(kind: StatusKind.warning, label: 'Due soon'),
              StatusBadge(kind: StatusKind.danger, label: 'Overdue'),
              StatusBadge(kind: StatusKind.neutral, label: 'Vacant'),
            ],
          ),
        ),
      ),
    );

    final colors = appLightTheme.extension<AppStatusColors>()!;
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Due soon'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Vacant'), findsOneWidget);

    Color textColor(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;
    expect(textColor('Paid'), colors.success);
    expect(textColor('Due soon'), colors.warning);
    expect(textColor('Overdue'), colors.danger);
    expect(textColor('Vacant'), colors.neutral);
  });

  testWidgets('badge pulls color from AppStatusColors, not a hardcoded value',
      (tester) async {
    const custom = AppStatusColors(
      success: Color(0xFF000000),
      warning: Color(0xFF111111),
      danger: Color(0xFF222222),
      neutral: Color(0xFF333333),
    );
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
    ).copyWith(extensions: [custom]);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: StatusBadge(kind: StatusKind.success, label: 'Paid'),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Paid'));
    expect(text.style!.color, const Color(0xFF000000));
  });
}