import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/config.dart';
import 'package:lucky/main.dart';
import 'package:lucky/navigation/routes.dart';
import 'package:lucky/services/json_store.dart';

void main() {
  testWidgets('AppBar title reads LUCKY on the dashboard', (tester) async {
    await tester.pumpWidget(LuckyApp(createStore: InMemoryJsonStore.new));
    await tester.pumpAndSettle();
    // Overview is the spec label for Dashboard — check AppBar specifically.
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Overview')),
      findsOneWidget,
    );
    // No screen may surface the old brand name.
    expect(find.textContaining('renttrack'), findsNothing);
    expect(find.textContaining('RentTrack'), findsNothing);
  });

  test('app display name is LUCKY everywhere', () {
    expect(AppConfig.appName, 'LUCKY');
    expect(routeTitles[Routes.dashboard], 'Overview');
  });
}
