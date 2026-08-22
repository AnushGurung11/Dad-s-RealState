import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/theme/app_theme.dart';
import 'package:lucky/widgets/lucky_wordmark.dart';

void main() {
  testWidgets('LUCKY wordmark renders symbol + wordmark using the theme accent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: const Scaffold(body: Center(child: LuckyWordmark())),
      ),
    );

    expect(find.byKey(const Key('lucky_wordmark')), findsOneWidget);
    expect(find.text('LUCKY'), findsOneWidget);

    // The wordmark text must use the theme accent color, not a hardcoded hue.
    final text = tester.widget<Text>(find.text('LUCKY'));
    expect(text.style?.color, appAccent);
  });

  testWidgets('wordmark renders under the dark theme too', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appDarkTheme,
        home: const Scaffold(body: Center(child: LuckyWordmark(size: 48))),
      ),
    );
    expect(find.text('LUCKY'), findsOneWidget);
  });
}
