import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/navigation/routes.dart';
import 'package:lucky/screens/settings_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';
import 'package:lucky/widgets/lucky_wordmark.dart';

void main() {
  late InMemoryJsonStore store;

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        routes: {
          Routes.archiveTenants: (context) =>
              const Scaffold(key: Key('tenants_archive_route'), body: Text('Tenant archive')),
          Routes.archiveFlats: (context) =>
              const Scaffold(key: Key('flats_archive_route'), body: Text('Flat archive')),
        },
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
  });

  testWidgets('no dark mode toggle or notifications section renders',
      (tester) async {
    await pumpSettings(tester);

    expect(find.text('Notifications'), findsNothing);
    expect(find.text('Lease cheque reminders'), findsNothing);
    expect(find.byKey(const Key('settings_theme_toggle')), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Dark Mode'), findsNothing);
  });

  testWidgets('Archive section shows both entries', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Archived Tenants'), findsOneWidget);
    expect(find.text('Archived Flats'), findsOneWidget);
  });

  testWidgets('Archived Tenants entry navigates to the tenant archive list',
      (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings_archived_tenants')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tenants_archive_route')), findsOneWidget);
  });

  testWidgets('Archived Flats entry navigates to the separate flat archive '
      'screen', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings_archive_flats')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flats_archive_route')), findsOneWidget);
  });

  testWidgets('About block renders the LUCKY wordmark', (tester) async {
    await pumpSettings(tester);

    // Scroll to find the About section
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byType(LuckyWordmark), findsOneWidget);
  });
}
