import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/theme/app_theme.dart';
import 'package:lucky/widgets/lucky_wordmark.dart';

void main() {
  testWidgets('LUCKY wordmark renders symbol + wordmark using spec neutral color',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appDarkTheme,
        home: const Scaffold(body: Center(child: LuckyWordmark())),
      ),
    );

    expect(find.byKey(const Key('lucky_wordmark')), findsOneWidget);
    expect(find.text('Lucky'), findsOneWidget);

    // Spec: header wordmark is neutral appText1, not accent
    final text = tester.widget<Text>(find.text('Lucky'));
    expect(text.style?.color, appText1);
  });

  testWidgets('wordmark renders under the dark theme too', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appDarkTheme,
        home: const Scaffold(body: Center(child: LuckyWordmark(size: 48))),
      ),
    );
    expect(find.text('Lucky'), findsOneWidget);
  });
}
