import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/legal_document.dart';
import 'package:lucky/screens/flat_legal_docs_screen.dart';
import 'package:lucky/services/json_store.dart';
import 'package:lucky/services/store_scope.dart';
import 'package:lucky/theme/app_theme.dart';

void main() {
  late InMemoryJsonStore store;

  LegalDocument doc(String id, String label, {String? description}) {
    return LegalDocument(
      id: id,
      flatId: 'f1',
      label: label,
      description: description,
      imagePath: '/nonexistent/legal_docs/$id.jpg',
      createdAt: DateTime(2026, 2, 1),
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        builder: (context, child) =>
            StoreScope(store: store, child: child ?? const SizedBox.shrink()),
        home: const FlatLegalDocsScreen(flatId: 'f1', flatName: 'Alpha'),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryJsonStore();
  });

  testWidgets('grid renders one card per document with label and description',
      (tester) async {
    store.upsertLegalDocument(doc('d1', 'Lease Contract', description: '2026'));
    store.upsertLegalDocument(doc('d2', 'DEWA Registration'));
    store.upsertLegalDocument(doc('d3', 'Inventory', description: 'Signed'));

    await pumpScreen(tester);

    expect(find.byType(Card), findsNWidgets(3));
    expect(find.text('Lease Contract'), findsOneWidget);
    expect(find.text('DEWA Registration'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    // A document with no description says so rather than showing a blank.
    expect(find.text('No description'), findsOneWidget);
  });

  testWidgets('app bar shows "<flatName> - Legal Docs"', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Alpha - Legal Docs'), findsOneWidget);
  });

  testWidgets('FAB is present with the "Add Document" label', (tester) async {
    store.upsertLegalDocument(doc('d1', 'Lease Contract'));
    await pumpScreen(tester);

    final fab = find.widgetWithText(FloatingActionButton, 'Add Document');
    expect(fab, findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
    expect(find.bySemanticsLabel('Add Document'), findsOneWidget);
  });

  testWidgets('empty state renders when the flat has no documents',
      (tester) async {
    // A document on another flat must not leak into this flat's grid.
    store.upsertLegalDocument(LegalDocument(
      id: 'other',
      flatId: 'f2',
      label: 'Other Flat Lease',
      imagePath: '/nonexistent/legal_docs/other.jpg',
      createdAt: DateTime(2026, 2, 1),
    ));

    await pumpScreen(tester);

    expect(find.text('No legal documents yet'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.text('Other Flat Lease'), findsNothing);
  });

  testWidgets('every card has edit and delete controls', (tester) async {
    store.upsertLegalDocument(doc('d1', 'Lease Contract'));
    store.upsertLegalDocument(doc('d2', 'DEWA Registration'));
    await pumpScreen(tester);

    expect(find.byIcon(Icons.edit), findsNWidgets(2));
    expect(find.byIcon(Icons.delete), findsNWidgets(2));
  });

  testWidgets('tapping a thumbnail opens the zoomable viewer', (tester) async {
    store.upsertLegalDocument(doc('d1', 'Lease Contract', description: '2026'));
    await pumpScreen(tester);

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
  });
}
