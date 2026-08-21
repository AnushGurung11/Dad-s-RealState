import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/screens/flat_detail_screen.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/store_scope.dart';
import 'package:renttrack/theme/app_theme.dart';
import 'package:renttrack/widgets/bed_row.dart';
import 'package:renttrack/widgets/status_badge.dart';

void main() {
  late InMemoryJsonStore store;

  final flat = Flat(
    id: 'f1',
    name: 'Alpha',
    address: '1 A Road',
    contractDate: DateTime(2026, 1, 15),
    contractPerson: 'Mr. Khan',
    yearlyRent: 60000,
    createdAt: DateTime(2026, 1, 1),
  );

  const bed1 = Bed(
      id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000,
      tenantId: 'p1');
  const bed2 = Bed(id: 'b2', flatId: 'f1', label: 'Bed 2', defaultMonthlyRent: 4500);

  final alice = Person(
    id: 'p1',
    name: 'Alice',
    contact: '9000000001',
    bedId: 'b1',
    joinDate: DateTime(2026, 2, 1),
    plannedStayMonths: 12,
  );

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const FlatDetailScreen(flatId: 'f1'),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertFlat(flat);
    store.upsertBed(bed1);
    store.upsertBed(bed2);
    store.upsertPerson(alice);
  });

  testWidgets('Beds tab lists all beds with correct occupied/vacant styling',
      (tester) async {
    await pumpDetail(tester);
    await tester.pumpAndSettle();

    // Default tab is Beds.
    expect(find.text('Bed 1'), findsOneWidget);
    expect(find.text('Bed 2'), findsOneWidget);

    // Occupied bed shows the occupant's name and rent.
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('AED 4000'), findsOneWidget);

    // Vacant bed shows the Vacant badge instead.
    expect(find.text('Vacant'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
  });

  testWidgets('Lease info tab shows contract fields, no payment history list',
      (tester) async {
    await pumpDetail(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lease info'));
    await tester.pumpAndSettle();

    expect(find.text('1 A Road'), findsOneWidget);
    expect(find.text('2026-01-15'), findsOneWidget);
    expect(find.text('Mr. Khan'), findsOneWidget);
    expect(find.text('AED 60000'), findsOneWidget);

    // No payment history on this tab — that lives in its own screen (chunk 6).
    expect(find.textContaining('Payment history'), findsNothing);
    expect(find.textContaining('Payments'), findsNothing);
  });

  testWidgets('editing a Lease info field persists via the store',
      (tester) async {
    await pumpDetail(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lease info'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit lease info'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '99 New Road',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contract person'),
      'Ms. Lee',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(store.flats.single.address, '99 New Road');
    expect(store.flats.single.contractPerson, 'Ms. Lee');

    // The read-only view reflects the edit.
    expect(find.text('99 New Road'), findsOneWidget);
  });

  testWidgets('an overdue occupant marks their bed row with the danger color',
      (tester) async {
    final now = DateTime.now();
    store.upsertPayment(Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month:
          '${now.year}-${now.month.toString().padLeft(2, '0')}',
      amountDue: 4000,
      amountPaid: 0,
      type: PaymentType.rent,
    ));

    await pumpDetail(tester);
    await tester.pumpAndSettle();

    final colors = appLightTheme.extension<AppStatusColors>()!;
    final row = tester.widget<BedRow>(
      find.byWidgetPredicate((w) => w is BedRow && w.bed.id == 'b1'),
    );
    expect(row.isOverdue, isTrue);
    expect(colors.danger, isNot(colors.neutral));
  });
}
