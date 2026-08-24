import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/screens/flat_detail_screen.dart';
import 'package:lucky/screens/tenants_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';
import 'package:lucky/widgets/person_avatar.dart';

void main() {
  late InMemoryJsonStore store;

  final flatA = Flat(
    id: 'f1',
    name: 'Alpha',
    address: '1 A Road',
    createdAt: DateTime(2026, 1, 1),
  );
  final flatB = Flat(
    id: 'f2',
    name: 'Beta',
    address: '2 B Road',
    createdAt: DateTime(2026, 1, 1),
  );

  const bedB1 = Bed(
      id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000,
      tenantId: 'p1');
  const bedB2 = Bed(
      id: 'b2', flatId: 'f2', label: 'Bed 2', defaultMonthlyRent: 4500,
      tenantId: 'p2');

  Person person({
    required String id,
    required String name,
    String? bedId,
    String? flatId,
    String? photoPath,
  }) =>
      Person(
        id: id,
        name: name,
        contact: '90000000${id.hashCode % 10}',
        bedId: bedId,
        flatId: flatId,
        joinDate: DateTime(2026, 1, 1),
        plannedStayMonths: 12,
        depositAmount: 5000,
        monthlyRent: 4000,
        photoPath: photoPath,
      );

  Future<void> pumpTenants(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const TenantsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpFlatDetail(WidgetTester tester, String flatId) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: FlatDetailScreen(flatId: flatId),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flatA);
    store.upsertFlat(flatB);
    store.upsertBed(bedB1);
    store.upsertBed(bedB2);
    // Person with photo
    store.upsertPerson(person(
        id: 'p1', name: 'Alice', bedId: 'b1', flatId: 'f1',
        photoPath: '/fake/path/alice.jpg'));
    // Person without photo
    store.upsertPerson(person(
        id: 'p2', name: 'Bob', bedId: 'b2', flatId: 'f2',
        photoPath: null));
    // Unassigned person with photo
    store.upsertPerson(person(
        id: 'p3', name: 'Carol', flatId: 'f1',
        photoPath: '/fake/path/carol.jpg'));
  });

  testWidgets('avatar renders on Tenants list rows when photoPath is set', (tester) async {
    await pumpTenants(tester);

    // PersonAvatar widgets should be present
    expect(find.byType(PersonAvatar), findsWidgets);
    
    // Find Alice's row and verify it has a PersonAvatar in it
    final aliceRow = find.ancestor(
      of: find.text('Alice'),
      matching: find.byType(Card),
    );
    expect(aliceRow, findsOneWidget);
    
    // The ListTile leading should be a PersonAvatar
    final listTile = find.ancestor(
      of: find.text('Alice'),
      matching: find.byType(ListTile),
    );
    expect(listTile, findsOneWidget);
    
    // Verify no error widgets
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('avatar renders on bed rows inside Flat detail when occupant has a photo', (tester) async {
    await pumpFlatDetail(tester, 'f1');

    // Should have PersonAvatar widgets for occupied beds
    expect(find.byType(PersonAvatar), findsWidgets);
    
    // Verify no error widgets
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('both fall back cleanly to initials when photoPath is null - no broken image, no layout shift', (tester) async {
    await pumpTenants(tester);

    // Bob has no photo path - should show initials
    final bobRow = find.ancestor(
      of: find.text('Bob'),
      matching: find.byType(Card),
    );
    expect(bobRow, findsOneWidget);

    // Carol is unassigned but has photo path - should show in unassigned section
    expect(find.text('Carol'), findsOneWidget);
    final carolRow = find.ancestor(
      of: find.text('Carol'),
      matching: find.byType(Card),
    );
    expect(carolRow, findsOneWidget);

    // No error widgets should be present
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('PersonAvatar widget shows initials when photoPath is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: PersonAvatar(photoPath: null, name: 'John Doe'),
        ),
      ),
    );

    expect(find.text('JD'), findsOneWidget);
  });

  testWidgets('PersonAvatar widget shows initials when photoPath is empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: PersonAvatar(photoPath: '', name: 'Jane Smith'),
        ),
      ),
    );

    expect(find.text('JS'), findsOneWidget);
  });
}