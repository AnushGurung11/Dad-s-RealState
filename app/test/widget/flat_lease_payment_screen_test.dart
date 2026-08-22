import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/lease_cheque_setting.dart';
import 'package:lucky/screens/flat_lease_payment_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';
import 'package:lucky/utils/format.dart';

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

  LeaseChequeSetting setting({
    String id = 's1',
    required String flatId,
    required DateTime nextDueDate,
  }) =>
      LeaseChequeSetting(
        id: id,
        flatId: flatId,
        ownerName: 'Owner',
        amount: 4000,
        nextDueDate: nextDueDate,
      );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: FlatLeasePaymentScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flatA);
    store.upsertFlat(flatB);
  });

  testWidgets('rows are sorted by due date ascending', (tester) async {
    final now = DateTime.now();
    store.upsertChequeSetting(setting(
        id: 's1', flatId: 'f2', nextDueDate: now.add(const Duration(days: 40))));
    store.upsertChequeSetting(setting(
        id: 's2', flatId: 'f1', nextDueDate: now.add(const Duration(days: 10))));

    await pumpScreen(tester);

    double topOf(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(topOf('Alpha'), lessThan(topOf('Beta')));
  });

  testWidgets('overdue rows are styled with the danger color', (tester) async {
    store.upsertChequeSetting(setting(
        id: 's3',
        flatId: 'f1',
        nextDueDate: DateTime.now().subtract(const Duration(days: 5))));

    await pumpScreen(tester);

    final danger = appLightTheme.extension<AppStatusColors>()!.danger;
    final text = tester.widget<Text>(find.text('5 days overdue'));
    expect(text.style?.color, danger);
  });

  testWidgets('pay flow records the payment and advances the row to the new '
      'due date — with no notification side effects', (tester) async {
    final due = DateTime(2026, 10, 25);
    store.upsertChequeSetting(setting(id: 's1', flatId: 'f1', nextDueDate: due));

    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('pay-s1')));
    await tester.pumpAndSettle();

    // Amount pre-filled from the setting.
    final field = tester.widget<TextFormField>(
        find.byKey(const Key('lease_amount_field')));
    expect(field.controller!.text, formatMoney(4000));

    await tester.enterText(
        find.byKey(const Key('lease_amount_field')), '3900');
    await tester.tap(find.byKey(const Key('record_lease_payment')));
    await tester.pumpAndSettle();

    // Old due date gone from the list; advanced one present.
    expect(find.textContaining('2026-10-25'), findsNothing);
    expect(find.textContaining('2026-12-25'), findsOneWidget);

    final record = store.leaseChequeRecords.single;
    expect(record.amount, 3900);
    expect(record.dueDate, due);
    expect(store.leaseChequeSettings.single.nextDueDate,
        DateTime(2026, 12, 25));
  });
}
