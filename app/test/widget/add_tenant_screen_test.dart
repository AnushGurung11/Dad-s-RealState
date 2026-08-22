import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/person.dart';
import 'package:lucky/screens/add_tenant_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/services/tenant_photo_picker.dart';
import 'package:lucky/theme/app_theme.dart';

/// Fake photo pipeline: never touches platform channels. Returns a STABLE
/// app-style path (not an OS picker temp path) so tests can assert what is
/// persisted.
class FakePhotoPicker implements TenantPhotoPicker {
  FakePhotoPicker([this._result = '/data/tenant_photos/photo_fake1.jpg']);

  final String? _result;
  int calls = 0;

  @override
  Future<String?> pickAndStore() async {
    calls++;
    return _result;
  }
}

void main() {
  late InMemoryJsonStore store;

  Future<void> pumpScreen(
    WidgetTester tester, {
    TenantPhotoPicker? picker,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: AddTenantScreen(photoPicker: picker),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
  });

  testWidgets('creates an UNASSIGNED person — no bed, no rent, no deposit',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Alice');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact'), '9000000001');
    await tester.tap(find.byKey(const Key('save_tenant_button')));
    await tester.pumpAndSettle();

    final person = store.people.single;
    expect(person.name, 'Alice');
    expect(person.bedId, isNull);
    expect(person.flatId, isNull);
    expect(person.monthlyRent, isNull);
    expect(person.depositAmount, isNull);
    expect(person.status, PersonStatus.active);
  });

  testWidgets('stores a stable local photoPath (never a transient OS picker '
      'path)', (tester) async {
    const transientPickerPath = '/cache/xyz_tmp_9182.jpg';
    // A realistic pipeline copies the pick into the documents dir; the fake
    // simulates the RESULT of that copy.
    final picker = FakePhotoPicker('/data/app_dir/tenant_photos/photo_a.jpg');
    await pumpScreen(tester, picker: picker);

    await tester.tap(find.byKey(const Key('add_tenant_photo_button')));
    await tester.pumpAndSettle();
    expect(picker.calls, 1);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Bob');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact'), '9000000002');
    await tester.tap(find.byKey(const Key('save_tenant_button')));
    await tester.pumpAndSettle();

    final person = store.people.single;
    expect(person.photoPath, isNotNull);
    expect(person.photoPath, contains('tenant_photos'));
    expect(person.photoPath, isNot(equals(transientPickerPath)));
  });

  testWidgets('cancelled photo pick leaves photoPath empty', (tester) async {
    await pumpScreen(tester, picker: FakePhotoPicker(null));

    await tester.tap(find.byKey(const Key('add_tenant_photo_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Cara');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact'), '9000000003');
    await tester.tap(find.byKey(const Key('save_tenant_button')));
    await tester.pumpAndSettle();

    expect(store.people.single.photoPath, isNull);
  });
}
