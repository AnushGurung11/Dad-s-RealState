import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/legal_document.dart';
import 'package:lucky/services/json_store.dart';

void main() {
  late InMemoryJsonStore store;

  LegalDocument doc({
    String id = 'doc1',
    String flatId = 'flat1',
    String label = 'Lease Contract',
    String? description = 'Signed',
    String imagePath = '/data/LUCKY/legal_docs/doc1.jpg',
  }) {
    return LegalDocument(
      id: id,
      flatId: flatId,
      label: label,
      description: description,
      imagePath: imagePath,
      createdAt: DateTime(2026, 2, 1),
    );
  }

  setUp(() {
    store = InMemoryJsonStore();
  });

  group('upsertLegalDocument', () {
    test('appends a new document', () {
      store.upsertLegalDocument(doc());

      expect(store.legalDocuments.length, 1);
      expect(store.legalDocuments.first.id, 'doc1');
      expect(store.legalDocuments.first.label, 'Lease Contract');
    });

    test('updates in place when the id already exists', () {
      store.upsertLegalDocument(doc());
      store.upsertLegalDocument(
        doc(label: 'Lease Contract 2027', description: 'Renewed'),
      );

      expect(store.legalDocuments.length, 1);
      final stored = store.legalDocuments.first;
      expect(stored.label, 'Lease Contract 2027');
      expect(stored.description, 'Renewed');
    });

    test('keeps the image path untouched by a label edit', () {
      store.upsertLegalDocument(doc());
      store.upsertLegalDocument(doc(label: 'Renamed'));

      expect(store.legalDocuments.first.imagePath,
          '/data/LUCKY/legal_docs/doc1.jpg');
    });

    test('the legalDocuments getter is unmodifiable', () {
      store.upsertLegalDocument(doc());
      expect(
        () => store.legalDocuments.add(doc(id: 'doc2')),
        throwsUnsupportedError,
      );
    });
  });

  group('deleteLegalDocument', () {
    test('removes only the requested record', () {
      store.upsertLegalDocument(doc(id: 'doc1', flatId: 'flat1'));
      store.upsertLegalDocument(doc(id: 'doc2', flatId: 'flat1'));
      store.upsertLegalDocument(doc(id: 'doc3', flatId: 'flat2'));

      store.deleteLegalDocument('doc2');

      final ids = store.legalDocuments.map((d) => d.id).toList();
      expect(ids, containsAll(<String>['doc1', 'doc3']));
      expect(ids, isNot(contains('doc2')));
    });

    test('is a no-op for an unknown id', () {
      store.upsertLegalDocument(doc());
      store.deleteLegalDocument('nope');
      expect(store.legalDocuments.length, 1);
    });
  });

  group('getLegalDocumentsForFlat', () {
    test('returns only that flat’s documents', () {
      store.upsertLegalDocument(doc(id: 'doc1', flatId: 'flat1'));
      store.upsertLegalDocument(doc(id: 'doc2', flatId: 'flat2'));
      store.upsertLegalDocument(doc(id: 'doc3', flatId: 'flat1'));

      final forFlat1 = store.getLegalDocumentsForFlat('flat1');

      expect(forFlat1.length, 2);
      expect(forFlat1.every((d) => d.flatId == 'flat1'), isTrue);
      expect(forFlat1.map((d) => d.id), containsAll(<String>['doc1', 'doc3']));
    });

    test('returns an empty list for a flat with no documents', () {
      store.upsertLegalDocument(doc(flatId: 'flat1'));
      expect(store.getLegalDocumentsForFlat('flat2'), isEmpty);
    });

    test('returns a new list, not a live view', () {
      store.upsertLegalDocument(doc(flatId: 'flat1'));

      final first = store.getLegalDocumentsForFlat('flat1');
      store.upsertLegalDocument(doc(id: 'doc2', flatId: 'flat1'));

      expect(first.length, 1);
      expect(store.getLegalDocumentsForFlat('flat1').length, 2);
    });
  });
}
