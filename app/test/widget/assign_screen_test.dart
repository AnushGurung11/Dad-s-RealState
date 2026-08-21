import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/screens/assign_screen.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/store_scope.dart';
import 'package:renttrack/theme/app_theme.dart';
import 'package:renttrack/theme/flat_color.dart';

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

  const bedA1 = Bed(id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000);
  const bedA2 = Bed(
      id: 'b2', flatId: 'f1', label: 'Bed 2', defaultMonthlyRent: 4200,
      tenantId: 'p9');
  const bedB1 = Bed(id: 'b3', flatId: 'f2', label: 'Bed 1', defaultMonthlyRent: 3000);

  Future<void> pumpAssign(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        // Mirrors the app shell: screens live inside a Scaffold so
        // ScaffoldMessenger snackbars have a presenter.
        home: const Scaffold(body: AssignScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flatA);
    store.upsertFlat(flatB);
    store.upsertBed(bedA1);
    store.upsertBed(bedA2);
    store.upsertBed(bedB1);
    store.upsertPerson(const Person(
        id: 'p1', name: 'Alice', contact: '9000000001'));
    store.upsertPerson(const Person(
        id: 'p9', name: 'Occupant', contact: '9000000009', bedId: 'b2',
        flatId: 'f1'));
  });

  /// Tapping the field itself (not the hint text) so the hit lands on the
  /// InputDecorator's gesture handler.
  Finder dropdownField(String hint) =>
      find.widgetWithText(DropdownButtonFormField<String>, hint);

  testWidgets('only unassigned people appear in the person picker',
      (tester) async {
    await pumpAssign(tester);

    await tester.tap(dropdownField('Select tenant'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Occupant'), findsNothing);
  });

  testWidgets('only vacant beds appear in the bed picker, grouped by flat '
      'with the correct flat color', (tester) async {
    await pumpAssign(tester);

    await tester.tap(dropdownField('Select bed'));
    await tester.pumpAndSettle();

    // Group headers for both flats are present.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    // Vacant beds listed; the occupied Bed 2 of Alpha is not.
    expect(find.text('Bed 1'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('bed-dot-b2')), findsNothing);

    // Each vacant bed's dot carries its flat's color.
    Color dotColor(String bedId) =>
        (tester.widget<Container>(find.byKey(ValueKey('bed-dot-$bedId')))
                    .decoration as BoxDecoration)
                .color!;
    expect(dotColor('b1'), flatColorFor('f1'));
    expect(dotColor('b3'), flatColorFor('f2'));
  });

  testWidgets('monthlyRent field pre-fills from the selected bed default and '
      'is editable', (tester) async {
    await pumpAssign(tester);

    await tester.tap(dropdownField('Select bed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bed-dot-b3')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '3000'), findsOneWidget,
        reason: 'rent pre-fills from Beta Bed 1 default');

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Monthly rent (AED)'), '3250');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '3250'), findsOneWidget,
        reason: 'the pre-filled rent stays editable');
  });

  testWidgets('"Currently assigned" list updates immediately after a new '
      'assignment is saved, without requiring a screen reload', (tester) async {
    await pumpAssign(tester);

    final listFinder = find.byType(ListView);

    // The list section sits below the fold of the lazy ListView. The fixture
    // already has Occupant on Alpha · Bed 2, so the section shows rows.
    await tester.drag(listFinder, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Currently assigned'), findsOneWidget);
    expect(find.text('Occupant'), findsOneWidget);

    // Back to the top to fill the form.
    await tester.drag(listFinder, const Offset(0, 1000));
    await tester.pumpAndSettle();

    await tester.tap(dropdownField('Select tenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    await tester.tap(dropdownField('Select bed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bed-dot-b1')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Deposit (AED)'), '5000');
    await tester.ensureVisible(find.text('Assign tenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Assign tenant'));
    await tester.pumpAndSettle();

    // The list below refreshed in place (scroll down to it).
    await tester.drag(listFinder, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('Currently assigned'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.textContaining('Bed 1 · AED 4000'), findsOneWidget);
    expect(store.people.singleWhere((p) => p.id == 'p1').bedId, 'b1');
  });
}
