import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/screens/archive_tenants_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  late InMemoryJsonStore store;

  const bed = Bed(
      id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000);

  final left = Person(
    id: 'p1',
    name: 'Alice',
    contact: '9000000001',
    bedId: 'b1',
    flatId: 'f1',
    joinDate: DateTime(2026, 1, 1),
    plannedStayMonths: 12,
    vacatedDate: DateTime(2026, 6, 30),
    status: PersonStatus.archived,
    statusDate: DateTime(2026, 7, 1),
  );
  final absconded = Person(
    id: 'p2',
    name: 'Bob',
    contact: '9000000002',
    bedId: 'b2',
    flatId: 'f1',
    joinDate: DateTime(2026, 2, 1),
    plannedStayMonths: 12,
    status: PersonStatus.absconded,
    statusDate: DateTime(2026, 7, 5),
    statusNote: 'left owing 1.5 months rent',
  );

  Future<void> pumpArchive(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const ArchiveTenantsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertBed(bed);
    store.upsertPerson(left);
    store.upsertPerson(absconded);
  });

  testWidgets('shows both archived and absconded people with distinct '
      'badges', (tester) async {
    await pumpArchive(tester);

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Left'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Absconded'), findsOneWidget);
  });

  testWidgets('absconded rows surface their statusNote', (tester) async {
    await pumpArchive(tester);

    expect(
      find.byKey(const ValueKey('status-note-p2')),
      findsOneWidget,
    );
    expect(find.textContaining('left owing 1.5 months'), findsOneWidget);
  });

  testWidgets('active people never appear in the archive', (tester) async {
    store.upsertPerson(const Person(
        id: 'p3', name: 'Cara', contact: '9000000003'));
    await pumpArchive(tester);

    expect(find.text('Cara'), findsNothing);
  });
}
