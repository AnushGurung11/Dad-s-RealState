import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/navigation/routes.dart';
import 'package:renttrack/screens/flats_screen.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/store_scope.dart';
import 'package:renttrack/theme/app_theme.dart';

void main() {
  late InMemoryJsonStore store;

  final flat = Flat(
    id: 'f1',
    name: 'Alpha',
    address: '1 A Road',
    contractPerson: 'Mr. Khan',
    yearlyRent: 60000,
    createdAt: DateTime(2026, 1, 1),
  );

  Future<void> pumpFlats(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        // StoreScope lives in the builder so pushed routes (the create form,
        // the detail screen) resolve it too.
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        routes: {
          Routes.flatDetail: (context) => const Scaffold(
                key: Key('detail_route'),
                body: Text('Detail'),
              ),
        },
        home: const FlatsScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flat);
    store.upsertBed(const Bed(
      id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000));
    store.upsertBed(const Bed(
      id: 'b2', flatId: 'f1', label: 'Bed 2', defaultMonthlyRent: 4000));
    store.upsertBed(const Bed(
      id: 'b3', flatId: 'f1', label: 'Bed 3', defaultMonthlyRent: 4000,
      tenantId: 'p1'));
  });

  testWidgets('grid card shows only name + occupancy count', (tester) async {
    await pumpFlats(tester);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('1 / 3 beds'), findsOneWidget);
    // Brief view must not leak detail fields onto the card.
    expect(find.textContaining('A Road'), findsNothing);
    expect(find.textContaining('60000'), findsNothing);
  });

  testWidgets('tapping a card opens detail on the Beds tab by default',
      (tester) async {
    await pumpFlats(tester);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail_route')), findsOneWidget);
  });

  testWidgets('creating a flat from the form persists it in the store',
      (tester) async {
    await pumpFlats(tester);

    await tester.tap(find.text('Add flat'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Flat name'), 'Beta');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Address'), '2 B Road');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contract person'), 'Ms. Lee');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Yearly rent (AED)'), '60000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Total beds'), '5');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Default rent per bed (AED)'),
        '3500');
    await tester.ensureVisible(find.text('Create flat'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create flat'));
    await tester.pumpAndSettle();

    expect(store.flats.map((f) => f.name), contains('Beta'));
    expect(
        store.beds.where((b) => b.flatId == store.flats.last.id), hasLength(5));
    expect(store.leaseChequeSettings, hasLength(1));
    expect(store.leaseChequeSettings.single.amount, closeTo(10000, 0.001));
    // Back on the grid, the new card is visible.
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('form rejects a bed count outside 5-20', (tester) async {
    await pumpFlats(tester);

    await tester.tap(find.text('Add flat'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Flat name'), 'Bad');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Address'), 'x');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Yearly rent (AED)'), '60000');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Total beds'), '21');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Default rent per bed (AED)'),
        '3500');
    await tester.ensureVisible(find.text('Create flat'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create flat'));
    await tester.pumpAndSettle();

    expect(store.flats.map((f) => f.name), isNot(contains('Bad')));
    expect(find.text('Must be 5–20'), findsOneWidget);
  });
}
