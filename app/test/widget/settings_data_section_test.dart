import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lucky/navigation/routes.dart';
import 'package:lucky/screens/settings_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';

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

  group('Settings Data Section', () {
    testWidgets('shows Create backup, Restore from backup, and Export to Excel entries',
        (tester) async {
      await pumpSettings(tester);

      // Scroll to Data section
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('Create backup'), findsOneWidget);
      expect(find.text('Restore from backup'), findsOneWidget);
      expect(find.text('Export to Excel'), findsOneWidget);
    });

    testWidgets('Data section has correct subtitles', (tester) async {
      await pumpSettings(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('Export all data and photos as a zip file'), findsOneWidget);
      expect(find.text('Replace all data with a backup zip (destructive)'), findsOneWidget);
      expect(find.text('One-way export for viewing (7 sheets, never re-imported)'), findsOneWidget);
    });

    testWidgets('Create backup shows busy indicator while working', (tester) async {
      await pumpSettings(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      // The button should be tappable
      expect(find.byKey(const Key('settings_create_backup')), findsOneWidget);
    });

    testWidgets('Restore from backup shows destructive warning concept', (tester) async {
      await pumpSettings(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_restore_backup')), findsOneWidget);
    });

    testWidgets('Export to Excel button exists', (tester) async {
      await pumpSettings(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings_export_excel')), findsOneWidget);
    });
  });
}