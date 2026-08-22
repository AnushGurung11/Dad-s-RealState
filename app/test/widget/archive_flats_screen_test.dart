import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/screens/archive_flats_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  late InMemoryJsonStore store;

  final activeFlat = Flat(
    id: 'f-active',
    name: 'Active Flat',
    address: '9 Live Road',
    createdAt: DateTime(2026, 1, 1),
  );

  final archivedFlat = Flat(
    id: 'f1',
    name: 'Old Flat',
    address: '1 A Road',
    registeredDate: DateTime(2025, 1, 15),
    contractPerson: 'Mr. Khan',
    yearlyRent: 60000,
    createdAt: DateTime(2025, 1, 1),
    archived: true,
    archivedAt: DateTime(2026, 5, 1),
  );

  const bed = Bed(
      id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000,
      tenantId: 'p1');

  final alice = Person(
    id: 'p1',
    name: 'Alice',
    contact: '9000000001',
    bedId: 'b1',
    flatId: 'f1',
    joinDate: DateTime(2025, 2, 1),
    plannedStayMonths: 12,
  );

  Future<void> pumpArchive(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const ArchiveFlatsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(activeFlat);
    store.upsertFlat(archivedFlat);
    store.upsertBed(bed);
    store.upsertPerson(alice);
  });

  testWidgets('lists only archived flats', (tester) async {
    await pumpArchive(tester);

    expect(find.text('Old Flat'), findsOneWidget);
    expect(find.text('Active Flat'), findsNothing);
  });

  testWidgets('shows the archive date on each row', (tester) async {
    await pumpArchive(tester);

    expect(find.textContaining('Archived 2026-05-01'), findsOneWidget);
  });

  testWidgets('tapping an archived flat shows its historical lease info and '
      'bed/tenant data read-only', (tester) async {
    await pumpArchive(tester);

    await tester.tap(find.text('Old Flat'));
    await tester.pumpAndSettle();

    // Historical lease fields.
    expect(find.text('Lease info'), findsOneWidget);
    expect(find.text('Flat registered on'), findsOneWidget);
    expect(find.text('2025-01-15'), findsOneWidget);
    expect(find.text('Mr. Khan'), findsOneWidget);

    // Bed + former occupant preserved.
    expect(find.text('Bed 1'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);

    // Read-only: no edit affordances anywhere.
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('empty state when nothing is archived', (tester) async {
    store.deleteFlat('f1');
    await pumpArchive(tester);

    expect(find.text('No archived flats.'), findsOneWidget);
  });
}
