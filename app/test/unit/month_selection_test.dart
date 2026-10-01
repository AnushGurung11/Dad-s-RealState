import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/expense.dart';
import 'package:lucky/models/flat.dart';
import 'package:lucky/models/lease_cheque_record.dart';
import 'package:lucky/models/payment.dart';
import 'package:lucky/config.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/month_selection.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/widgets/month_picker_bar.dart';

void main() {
  group('MonthSelection', () {
    test('defaults to the live calendar month', () {
      expect(MonthSelection().month, monthKey(DateTime.now()));
    });

    test('previous/next walk months and cross a year boundary', () {
      final selection = MonthSelection(initialMonth: '2026-01');

      selection.previous();
      expect(selection.month, '2025-12');

      selection.next();
      selection.next();
      expect(selection.month, '2026-02');
    });

    test('isCurrentMonth tracks the live month only', () {
      final selection = MonthSelection();
      expect(selection.isCurrentMonth, isTrue);

      selection.previous();
      expect(selection.isCurrentMonth, isFalse);

      selection.reset();
      expect(selection.isCurrentMonth, isTrue);
    });

    test('malformed keys fall back to the current month instead of throwing',
        () {
      expect(MonthSelection.normalize('not-a-month'), monthKey(DateTime.now()));
      expect(MonthSelection.normalize('2026-13'), monthKey(DateTime.now()));
      expect(MonthSelection.normalize('2026-00'), monthKey(DateTime.now()));
      expect(MonthSelection.normalize(''), monthKey(DateTime.now()));
    });

    test('label renders a readable month name', () {
      expect(MonthSelection.label('2026-09'), 'Sep 2026');
      expect(MonthSelection.label('2026-01'), 'Jan 2026');
      expect(MonthSelection.label('2026-12'), 'Dec 2026');
    });

    test('notifies listeners only when the month actually changes', () {
      final selection = MonthSelection(initialMonth: '2026-05');
      var notifications = 0;
      selection.addListener(() => notifications++);

      selection.select('2026-05');
      expect(notifications, 0);

      selection.select('2026-06');
      expect(notifications, 1);
    });
  });

  group('MonthSelection.monthsWithData', () {
    test('collects months from payments, expenses and lease records, newest first',
        () {
      final store = InMemoryJsonStore();
      store.upsertFlat(Flat(
          id: 'f1', name: 'A', address: 'x', createdAt: DateTime(2026, 1, 1)));
      store.upsertPayment(Payment(
        id: 'p1',
        personId: 'person1',
        bedId: 'b1',
        flatId: 'f1',
        month: '2026-03',
        amountDue: 1000,
        amountPaid: 1000,
      ));
      store.upsertExpense(Expense(
        id: 'e1',
        flatId: 'f1',
        category: ExpenseCategory.electricity,
        amount: 200,
        date: DateTime(2026, 2, 14),
      ));
      store.upsertChequeRecord(LeaseChequeRecord(
        id: 'r1',
        flatId: 'f1',
        ownerName: 'Owner',
        amount: 4000,
        dueDate: DateTime(2026, 5, 1),
        paidDate: DateTime(2026, 1, 9),
      ));

      final months = MonthSelection.monthsWithData(store);

      // Data months present, newest first, plus the current month always.
      expect(months, contains('2026-03'));
      expect(months, contains('2026-02'));
      expect(months, contains('2026-01'));
      expect(months, contains(monthKey(DateTime.now())));
      expect(months.first, monthKey(DateTime.now()));
    });

    test('a lease record is filed under its paid month, not its due month', () {
      final store = InMemoryJsonStore();
      store.upsertFlat(Flat(
          id: 'f1', name: 'A', address: 'x', createdAt: DateTime(2026, 1, 1)));
      store.upsertChequeRecord(LeaseChequeRecord(
        id: 'r1',
        flatId: 'f1',
        ownerName: 'Owner',
        amount: 4000,
        dueDate: DateTime(2026, 5, 1),
        paidDate: DateTime(2026, 3, 2),
      ));

      final months = MonthSelection.monthsWithData(store);

      expect(months, contains('2026-03'));
      expect(months, isNot(contains('2026-05')));
    });

    test('always includes the current month even with an empty store', () {
      final months = MonthSelection.monthsWithData(InMemoryJsonStore());
      expect(months, [monthKey(DateTime.now())]);
    });
  });

  group('MonthScope', () {
    Widget wrap(Widget child, MonthSelection? selection) {
      final content = MaterialApp(
        home: Builder(
          builder: (context) => Column(children: [
            Text('month=${MonthScope.monthOf(context)}'),
            child,
          ]),
        ),
      );
      if (selection == null) return content;
      return MonthScope(selection: selection, child: content);
    }

    testWidgets('monthOf falls back to the current month with no scope',
        (tester) async {
      await tester.pumpWidget(wrap(const SizedBox(), null));
      expect(find.text('month=${monthKey(DateTime.now())}'), findsOneWidget);
    });

    testWidgets('monthOf exposes the mounted selection', (tester) async {
      await tester
          .pumpWidget(wrap(const SizedBox(), MonthSelection(initialMonth: '2026-04')));
      expect(find.text('month=2026-04'), findsOneWidget);
    });

    testWidgets('selecting a month rebuilds dependents', (tester) async {
      final selection = MonthSelection(initialMonth: '2026-04');
      await tester.pumpWidget(wrap(const SizedBox(), selection));

      selection.select('2026-02');
      await tester.pump();

      expect(find.text('month=2026-02'), findsOneWidget);
    });
  });

  group('MonthPickerBar', () {
    testWidgets('renders nothing when no MonthScope is mounted', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MonthPickerBar()),
      ));
      expect(find.byKey(const Key('month_prev')), findsNothing);
    });

    testWidgets('stepping back updates the label and offers a way back',
        (tester) async {
      final selection = MonthSelection();
      final store = InMemoryJsonStore();

      await tester.pumpWidget(MonthScope(
        selection: selection,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(children: [
                const MonthPickerBar(),
                Text('body=${MonthScope.monthOf(context)}'),
              ]),
            ),
          ),
        ),
      ));
      // StoreScope is absent, so the picker degrades without the jump menu.
      expect(find.byKey(const Key('month_next')), findsOneWidget);

      await tester.tap(find.byKey(const Key('month_prev')));
      await tester.pump();

      final expected = MonthSelection.normalize(
          monthKey(DateTime(DateTime.now().year, DateTime.now().month - 1, 1)));
      expect(find.text('body=$expected'), findsOneWidget);
      expect(find.byKey(const Key('month_today')), findsOneWidget);
      expect(store.payments, isEmpty);
    });

    testWidgets('the jump menu lists months that hold data', (tester) async {
      final selection = MonthSelection();
      final store = InMemoryJsonStore();
      store.upsertFlat(Flat(
          id: 'f1', name: 'A', address: 'x', createdAt: DateTime(2026, 1, 1)));
      store.upsertExpense(Expense(
        id: 'e1',
        flatId: 'f1',
        category: ExpenseCategory.electricity,
        amount: 100,
        date: DateTime(2026, 2, 5),
      ));

      await tester.pumpWidget(MonthScope(
        selection: selection,
        child: StoreScope(
          store: store,
          child: const MaterialApp(
            home: Scaffold(body: MonthPickerBar()),
          ),
        ),
      ));

      expect(find.byKey(const Key('month_jump_menu')), findsOneWidget);

      await tester.tap(find.byKey(const Key('month_jump_menu')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('month_option_2026-02')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('month_option_2026-02')));
      await tester.pumpAndSettle();

      expect(selection.month, '2026-02');
    });
  });

  group('LeaseChequeRecord month derivation', () {
    test('month comes from paidDate', () {
      final record = LeaseChequeRecord(
        id: 'r1',
        flatId: 'f1',
        ownerName: 'Owner',
        amount: 100,
        dueDate: DateTime(2026, 12, 1),
        paidDate: DateTime(2026, 11, 27),
      );
      expect(record.month, '2026-11');
    });

    test('fromJson re-derives the month from paidDate, repairing stored data',
        () {
      final record = LeaseChequeRecord.fromJson({
        'id': 'r1',
        'flatId': 'f1',
        'ownerName': 'Owner',
        'amount': 100,
        'dueDate': '2026-12-01',
        'paidDate': '2026-11-27',
        // Legacy record: month was stored from the due date.
        'month': '2026-12',
      });

      expect(record.month, '2026-11');
    });

    test('toJson still writes month for readable exports', () {
      final record = LeaseChequeRecord(
        id: 'r1',
        flatId: 'f1',
        ownerName: 'Owner',
        amount: 100,
        dueDate: DateTime(2026, 12, 1),
        paidDate: DateTime(2026, 11, 27),
      );

      expect(record.toJson()['month'], '2026-11');
    });

    test('copyWith preserves the derived month', () {
      final record = LeaseChequeRecord(
        id: 'r1',
        flatId: 'f1',
        ownerName: 'Owner',
        amount: 100,
        dueDate: DateTime(2026, 12, 1),
        paidDate: DateTime(2026, 11, 27),
      );

      expect(record.copyWith(amount: 250).month, '2026-11');
      expect(record.copyWith(paidDate: DateTime(2026, 10, 2)).month, '2026-10');
    });
  });
}
