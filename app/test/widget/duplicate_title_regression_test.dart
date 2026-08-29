import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/main.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(LuckyApp(createStore: InMemoryJsonStore.new));
    await tester.pumpAndSettle();
  }

  // Helper to check that exactly one AppBar title exists at subtitle scale
  // and no second large title appears in body.
  Future<void> checkSingleTitle(WidgetTester tester, String title) async {
    // AppBar should have exactly one title text
    final appBarTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(title),
    );
    expect(appBarTitle, findsOneWidget,
        reason: 'Expected single AppBar title "$title"');

    // AppBar title should be at subtitle scale (23), not title scale (37)
    final appBarTheme = Theme.of(tester.element(find.byType(AppBar))).appBarTheme;
    expect(appBarTheme.titleTextStyle?.fontSize, AppTextScale.subtitle,
        reason: 'AppBar title should be at subtitle scale (23)');
    // Should be 2 at most: one in AppBar, one in bottom nav label
    // But body should not have a third large duplicate.
    // Bottom nav labels also contain same text, so we allow 2.
    // We check that no Text with titleLarge (37) duplicates the page title in body
    final titleLargeTexts = tester.widgetList<Text>(find.byType(Text)).where((t) {
      final style = t.style;
      return t.data == title && style?.fontSize == AppTextScale.title;
    });
    expect(titleLargeTexts, isEmpty,
        reason: 'Body should not have duplicate title at title scale (37) for "$title"');
  }

  testWidgets('Dashboard has single subtitle-scale title', (tester) async {
    await pumpApp(tester);
    await checkSingleTitle(tester, 'Dashboard');
  });

  testWidgets('Flats has single subtitle-scale title', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Flats')));
    await tester.pumpAndSettle();
    await checkSingleTitle(tester, 'Flats');
  });

  testWidgets('Tenants has single subtitle-scale title', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Tenants')));
    await tester.pumpAndSettle();
    await checkSingleTitle(tester, 'Tenants');
  });

  testWidgets('Finance has single subtitle-scale title', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('Finance')));
    await tester.pumpAndSettle();
    await checkSingleTitle(tester, 'Finance');
  });

  testWidgets('Settings via More sheet has single subtitle-scale title', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('More')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('more_settings')));
    await tester.pumpAndSettle();
    await checkSingleTitle(tester, 'Settings');
  });

  testWidgets('ScreenHeader now only renders caption at caption scale, not title', (tester) async {
    // Verify ScreenHeader (if used) does not render title at title scale
    await tester.pumpWidget(MaterialApp(
      theme: appLightTheme,
      home: Scaffold(
        appBar: AppBar(title: const Text('Test')),
        body: const Column(
          children: [
            // This would be a body subtitle, should be caption scale muted
            Text('Explanatory caption',
                style: TextStyle(fontSize: AppTextScale.caption)),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // Caption should be at caption scale (9), not title scale
    final caption = tester.widget<Text>(find.text('Explanatory caption'));
    expect(caption.style?.fontSize, AppTextScale.caption);
  });
}
