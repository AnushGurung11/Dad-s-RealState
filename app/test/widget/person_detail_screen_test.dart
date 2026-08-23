import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/screens/person_detail_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  late InMemoryJsonStore store;

  const bed = Bed(id: 'b1', flatId: 'f1', label: 'Bed 1', defaultMonthlyRent: 4000);

  Person activeTenant() => const Person(
        id: 'p1',
        name: 'Alice',
        contact: '9000000001',
        bedId: 'b1',
        flatId: 'f1',
        joinDate: null,
        plannedStayMonths: null,
      );

  Future<void> pumpDetail(WidgetTester tester) async {
    // Tall viewport so the whole lazy ListView (actions + history) builds.
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
  });

  Person tenant({DateTime? joinDate, int months = 12}) {
    final vacated = joinDate == null
        ? null
        : DateTime(joinDate.year, joinDate.month + months, joinDate.day);
    return Person(
      id: 'p1',
      name: 'Alice',
      contact: '9000000001',
      bedId: 'b1',
      flatId: 'f1',
      joinDate: joinDate,
      plannedStayMonths: joinDate == null ? null : months,
      vacatedDate: vacated,
      depositAmount: 5000,
      monthlyRent: 4000,
      others: 'Quiet tenant',
    );
  }

  testWidgets('Renew stay form updates vacatedDate and is reflected '
      'immediately', (tester) async {
    final joinDate = DateTime(2026, 2, 1);
    store.upsertPerson(tenant(joinDate: joinDate));
    await pumpDetail(tester);

    // Initial plan: Feb 2026 + 12 months.
    expect(find.text('2027-02-01'), findsOneWidget);

    await tester.tap(find.text('Renew stay'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('renew_months_field')), '3');
    await tester.tap(find.text('Extend'));
    await tester.pumpAndSettle();

    // Vacated date recomputed to +15 months and shown without a reload.
    expect(find.text('2027-05-01'), findsOneWidget);
    final person = store.people.single;
    expect(person.plannedStayMonths, 15);
    expect(person.renewalHistory, hasLength(1));
  });

  testWidgets('shows tenure summary fields and read-only payment history',
      (tester) async {
    final joinDate = DateTime(2026, 2, 1);
    store.upsertPerson(tenant(joinDate: joinDate));
    store.upsertPayment(const Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: '2026-02',
      amountDue: 4000,
      amountPaid: 4000,
      type: PaymentType.rent,
    ));
    await pumpDetail(tester);

    expect(find.text('AED 4000'), findsNWidgets(2)); // rent + payment row
    expect(find.text('AED 5000'), findsOneWidget); // deposit
    expect(find.text('2026-02-01'), findsOneWidget); // join date
    expect(find.text('Quiet tenant'), findsOneWidget);
    expect(find.text('2026-02'), findsOneWidget); // payment month
    // Balance: 12 × 4000 − 5000 − 4000.
    expect(find.textContaining('AED 39'), findsOneWidget);
  });

  testWidgets('no payment-entry control exists on this screen',
      (tester) async {
    final joinDate = DateTime(2026, 2, 1);
    store.upsertPerson(tenant(joinDate: joinDate));
    await pumpDetail(tester);

    // No money-entry affordances anywhere on the detail screen.
    expect(find.textContaining('Add payment'), findsNothing);
    expect(find.textContaining('Record payment'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    // The only action button is Renew stay.
    expect(find.widgetWithText(FilledButton, 'Renew stay'), findsOneWidget);
  });

  testWidgets('renew stay is disabled for a tenant without an active '
      'assignment', (tester) async {
    store.upsertPerson(activeTenant());
    await pumpDetail(tester);

    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Renew stay'));
    expect(button.onPressed, isNull);
  });
}
