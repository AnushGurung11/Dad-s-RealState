import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/screens/person_detail_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';

/// Delete vs absconded UI rules on the person detail screen.
void main() {
  late InMemoryJsonStore store;

  const bed = Bed(
      id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000,
      tenantId: 'p1');

  final alice = Person(
    id: 'p1',
    name: 'Alice',
    contact: '9000000001',
    bedId: 'b1',
    flatId: 'f1',
    joinDate: DateTime(2026, 1, 1),
    plannedStayMonths: 12,
    depositAmount: 5000,
    monthlyRent: 4000,
  );

  Future<void> pumpDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const PersonDetailScreen(personId: 'p1'),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertBed(bed);
    store.upsertPerson(alice);
  });

  testWidgets('Delete is enabled and works for a payment-free person',
      (tester) async {
    await pumpDetail(tester);

    // Actions are now in a popup menu
    await tester.tap(find.byKey(const Key('person_actions_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete tenant'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_person')));
    await tester.pumpAndSettle();

    expect(store.people.where((p) => p.id == 'p1'), isEmpty);
    expect(store.beds.single.tenantId, isNull);
  });

  testWidgets('Delete disappears for a person WITH payment history; '
      '"Mark as absconded" is offered instead', (tester) async {
    store.upsertPayment(Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: '2026-02',
      amountDue: 4000,
      amountPaid: 1000,
      type: PaymentType.rent,
    ));

    await pumpDetail(tester);

    // Open menu — delete should not be there
    await tester.tap(find.byKey(const Key('person_actions_menu')));
    await tester.pumpAndSettle();
    expect(find.text('Delete tenant'), findsNothing);
    expect(find.text('Mark as absconded'), findsOneWidget);
  });

  testWidgets('"Mark as absconded" requires a note before confirming',
      (tester) async {
    await pumpDetail(tester);

    await tester.tap(find.byKey(const Key('person_actions_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as absconded'));
    await tester.pumpAndSettle();

    final confirm =
        tester.widget<FilledButton>(find.byKey(const Key('confirm_absconded')));
    expect(confirm.onPressed, isNull);

    await tester.enterText(
        find.byKey(const Key('absconded_note_field')),
        'left owing 1.5 months');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_absconded')));
    await tester.pumpAndSettle();

    final updated = store.people.single;
    expect(updated.status, PersonStatus.absconded);
    expect(updated.statusNote, 'left owing 1.5 months');
    expect(store.beds.single.tenantId, isNull);
  });

  testWidgets('Edit opens the edit flow without touching bed or status',
      (tester) async {
    await pumpDetail(tester);

    // Edit is now in the popup menu
    await tester.tap(find.byKey(const Key('person_actions_menu')));
    await tester.pumpAndSettle();
    expect(find.text('Edit details'), findsOneWidget);
  });
}
