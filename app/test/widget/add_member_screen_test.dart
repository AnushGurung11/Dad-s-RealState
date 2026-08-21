import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renttrack/screens/add_member_screen.dart';
import 'package:renttrack/services/json_store.dart';
import 'package:renttrack/services/store_scope.dart';
import 'package:renttrack/theme/app_theme.dart';

void main() {
  late InMemoryJsonStore store;

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const AddMemberScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
  });

  testWidgets('creates a Person with no bedId/flatId/monthlyRent/deposit set',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Alice');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact'), '0501234567');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Workplace / info'), 'Acme LLC');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes'), 'Night shift worker');
    await tester.ensureVisible(find.text('Save member'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save member'));
    await tester.pumpAndSettle();

    expect(store.people, hasLength(1));
    final person = store.people.single;
    expect(person.name, 'Alice');
    expect(person.contact, '0501234567');
    expect(person.workplaceOrInfo, 'Acme LLC');
    expect(person.others, 'Night shift worker');
    // Unassigned by design — rent/deposit are captured at assignment.
    expect(person.bedId, isNull);
    expect(person.flatId, isNull);
    expect(person.monthlyRent, isNull);
    expect(person.depositAmount, isNull);
    expect(person.joinDate, isNull);
    expect(person.renewalHistory, isEmpty);
  });

  testWidgets('requires name and contact', (tester) async {
    await pumpScreen(tester);

    await tester.ensureVisible(find.text('Save member'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save member'));
    await tester.pumpAndSettle();

    expect(store.people, isEmpty);
    expect(find.text('Required'), findsNWidgets(2));
  });
}
