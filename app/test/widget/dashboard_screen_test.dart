import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/models/bed.dart';
import 'package:renttrack/models/flat.dart';
import 'package:renttrack/models/payment.dart';
import 'package:renttrack/models/person.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/widgets/summary_card.dart';

import '../helpers.dart';

void main() {
  testWidgets('renders summary cards and who-owes-what from a fake store',
      (tester) async {
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha House',
      address: '1 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertFlat(Flat(
      id: 'f2',
      name: 'Beta House',
      address: '2 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertBed(const Bed(id: 'b1', flatId: 'f1', label: 'Bed A1', monthlyRent: 4000));
    store.upsertBed(const Bed(id: 'b2', flatId: 'f1', label: 'Bed A2', monthlyRent: 4000, tenantId: 'p1'));
store.upsertPerson(Person(
      id: 'p1',
      name: 'Alice',
      contact: '9000000001',
      bedId: 'b2',
      joinDate: DateTime(2026, 1, 1),
      plannedStayMonths: 6,
      leaveDate: DateTime(2026, 7, 1),
      depositAmount: 5000,
    ));
    store.upsertPayment(const Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b2',
      flatId: 'f1',
      month: '2026-06',
      amountDue: 4000,
      amountPaid: 1000,
    ));

await pumpApp(tester, store: store, prefs: {'currentMonth': '2026-06'});

    expect(
      find.descendant(
        of: find.byType(SummaryCard),
        matching: find.text('Flats'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SummaryCard),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.text('Beds occupied'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(SummaryCard, 'Beds occupied'),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.text('Beds vacant'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(SummaryCard, 'Beds vacant'),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Net (2026-06)'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(SummaryCard, 'Net (2026-06)'),
        matching: find.text('Rs. 1000'),
      ),
      findsOneWidget,
    );

    expect(find.text('Who owes what — 2026-06'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Owes Rs. 3000'), findsOneWidget);
  });

  testWidgets('shows empty state with zero flats', (tester) async {
    await pumpApp(tester);

    expect(
      find.text('Add a flat, bed and tenant to see the dashboard summary.'),
      findsOneWidget,
    );
    expect(find.text('Go to Flats'), findsOneWidget);
  });

  testWidgets('no outstanding payments shows the all-clear message',
      (tester) async {
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha House',
      address: '1 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertBed(const Bed(id: 'b1', flatId: 'f1', label: 'Bed A1', monthlyRent: 4000));
    store.upsertPerson(Person(
      id: 'p1',
name: 'Alice',
      contact: '9000000001',
      bedId: 'b1',
    ));
    store.upsertPayment(const Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: '2026-06',
      amountDue: 4000,
      amountPaid: 4000,
    ));

    await pumpApp(tester, store: store, prefs: {'currentMonth': '2026-06'});

    expect(find.text('No outstanding payments for 2026-06.'), findsOneWidget);
  });

  testWidgets('tap through to a person payment history', (tester) async {
    final store = InMemoryJsonStore();
    store.upsertFlat(Flat(
      id: 'f1',
      name: 'Alpha House',
      address: '1 Main St',
      createdAt: DateTime(2026, 1, 1),
    ));
    store.upsertBed(const Bed(id: 'b1', flatId: 'f1', label: 'Bed A1', monthlyRent: 4000));
    store.upsertPerson(Person(
      id: 'p1',
name: 'Alice',
      contact: '9000000001',
      bedId: 'b1',
    ));
    store.upsertPayment(const Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: '2026-05',
      amountDue: 4000,
      amountPaid: 0,
    ));
    store.upsertPayment(const Payment(
      id: 'pay2',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: '2026-06',
      amountDue: 4000,
      amountPaid: 0,
    ));

    await pumpApp(tester, store: store, prefs: {'currentMonth': '2026-06'});

await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2026-05'), findsOneWidget);
    expect(find.textContaining('2026-06'), findsOneWidget);
  });
}
