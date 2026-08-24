import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/bed.dart';
import 'package:lucky/models/lease_termination_record.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/screens/termination_flow_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/services/termination_service.dart';
import 'package:lucky/theme/app_theme.dart';
import 'package:lucky/utils/format.dart';

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

  Future<void> pumpFlow(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const TerminationFlowScreen(personId: 'p1'),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
    store.upsertBed(bed);
    store.upsertPerson(alice);
  });

  void payMonths(List<String> months) {
    for (var i = 0; i < months.length; i++) {
      store.upsertPayment(Payment(
        id: 'pay$i',
        personId: 'p1',
        bedId: 'b1',
        flatId: 'f1',
        month: months[i],
        amountDue: 4000,
        amountPaid: 4000,
        type: PaymentType.rent,
      ));
    }
  }

  testWidgets('selecting "Other" reveals the note field and blocks submit '
      'until it is filled', (tester) async {
    // Tall viewport so the entire form fits without scrolling.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    
    await pumpFlow(tester);

    // Note field hidden for the default reason.
    expect(find.byKey(const Key('termination_note_field')), findsNothing);

    await tester.tap(find.byKey(const Key('termination_reason_picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('termination_note_field')), findsOneWidget);

    // Confirm stays disabled (both ack + required note).
    var confirm =
        tester.widget<FilledButton>(find.byKey(const Key('confirm_termination')));
    expect(confirm.onPressed, isNull);

    await tester.enterText(
        find.byKey(const Key('termination_note_field')), 'owner decided');
    await tester.ensureVisible(find.byKey(const Key('termination_ack')));
    await tester.pumpAndSettle();
    await tester.tap(find
        .descendant(
          of: find.byKey(const Key('termination_ack')),
          matching: find.byType(Checkbox),
        )
        .first);
    await tester.pumpAndSettle();

    confirm =
        tester.widget<FilledButton>(find.byKey(const Key('confirm_termination')));
    expect(confirm.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('confirm_termination')));
    await tester.pumpAndSettle();

    expect(store.terminations.single.reason, TerminationReason.other);
    expect(store.terminations.single.reasonNote, 'owner decided');
  });

  void payCurrentAndNextMonths() {
    final now = DateTime.now();
    String m(int offset) =>
        '${DateTime(now.year, now.month + offset).year}-'
        '${DateTime(now.year, now.month + offset).month.toString().padLeft(2, '0')}';
    store.upsertPayment(Payment(
      id: 'pay0',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: m(0),
      amountDue: 4000,
      amountPaid: 4000,
      type: PaymentType.rent,
    ));
    store.upsertPayment(Payment(
      id: 'pay1',
      personId: 'p1',
      bedId: 'b1',
      flatId: 'f1',
      month: m(1),
      amountDue: 4000,
      amountPaid: 4000,
      type: PaymentType.rent,
    ));
  }

  testWidgets('the breakdown matches termination_service exactly — refund '
      'includes unused final-month share plus all future prepaid months',
      (tester) async {
    payCurrentAndNextMonths();
    await pumpFlow(tester);

    final expected = TerminationService.calculate(
      alice,
      store.payments,
      DateTime.now(),
    );

    final shown = tester.widget<Text>(find.byKey(const Key('refund_amount')));
    expect(shown.data, formatMoneyShort(expected.refundAmount));

    await tester.tap(find.descendant(of: find.byKey(const Key('termination_ack')), matching: find.byType(Checkbox)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_termination')));
    await tester.pumpAndSettle();

    final record = store.terminations.single;
    expect(record.refundAmount, closeTo(expected.refundAmount, 0.001));
    expect(record.totalPaidAcrossPrepaidMonths, 8000);
  });

  testWidgets('a successful flow archives the person and frees the bed',
      (tester) async {
    await pumpFlow(tester);

    await tester.tap(find.descendant(of: find.byKey(const Key('termination_ack')), matching: find.byType(Checkbox)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_termination')));
    await tester.pumpAndSettle();

    expect(store.people.single.status, PersonStatus.archived);
    expect(store.beds.single.tenantId, isNull);
  });
}
