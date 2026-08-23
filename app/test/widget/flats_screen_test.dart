import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/navigation/routes.dart';
import 'package:lucky/screens/flats_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';

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

  testWidgets('Edit button opens the flat picker, then the combined '
      'flat+beds edit form', (tester) async {
    // Tall viewport so every lazy ListView item is built.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A valid flat needs at least 5 beds or the save is blocked by the
    // capacity rule.
    store.upsertBed(const Bed(
        id: 'b4', flatId: 'f1', label: 'Bed 4', defaultMonthlyRent: 4000));
    store.upsertBed(const Bed(
        id: 'b5', flatId: 'f1', label: 'Bed 5', defaultMonthlyRent: 4000));

    await pumpFlats(tester);

    await tester.tap(find.byKey(const Key('edit_flats_button')));
    await tester.pumpAndSettle();

    // Picker lists active flats only.
    expect(find.text('Edit which flat?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pick-flat-f1')));
    await tester.pumpAndSettle();

    // Combined form: flat fields AND bed drafts are present.
    expect(find.text('Edit flat'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Flat name'), findsOneWidget);
    expect(find.byKey(const Key('bed-draft-b1')), findsOneWidget);
    expect(find.byKey(const Key('bed-draft-b2')), findsOneWidget);

    // Edit a bed label and save.
    await tester.enterText(
      find
          .descendant(
            of: find.byKey(const Key('bed-draft-b1')),
            matching: find.byType(TextFormField),
          )
          .first,
      'Bed One',
    );
    await tester.tap(find.byKey(const Key('save_flat_edit')));
    await tester.pumpAndSettle();

    expect(store.beds.where((b) => b.id == 'b1').single.label, 'Bed One');
  });

  testWidgets('delete on a history-free flat warns of permanent deletion '
      'and removes it from the grid entirely', (tester) async {
    await pumpFlats(tester);

    await tester.tap(find.byKey(const Key('delete-flat-f1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('permanently deleted'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_delete_flat')));
    await tester.pumpAndSettle();

    // Hard delete: flat AND its beds are gone from the store.
    expect(store.flats, isEmpty);
    expect(store.beds.where((b) => b.flatId == 'f1'), isEmpty);
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets('delete on a flat with payment history warns it will be '
      'archived and moves it out of the main grid', (tester) async {
    store.upsertPayment(Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b3',
      flatId: 'f1',
      month: '2026-01',
      amountDue: 4000,
      amountPaid: 4000,
      type: PaymentType.rent,
    ));

    await pumpFlats(tester);

    await tester.tap(find.byKey(const Key('delete-flat-f1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('will be archived'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_delete_flat')));
    await tester.pumpAndSettle();

    // Soft delete: flat stays in the store but leaves the main grid.
    expect(store.flats.single.archived, isTrue);
    expect(store.flats.single.archivedAt, isNotNull);
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets('archived flats never render in the grid', (tester) async {
    store.upsertFlat(flat.copyWith(archived: true));
    await pumpFlats(tester);

    expect(find.text('Alpha'), findsNothing);
  });
}
