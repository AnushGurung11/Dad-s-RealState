import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/models/legal_document.dart';

void main() {
  final createdAt = DateTime(2026, 3, 4, 10, 30);

  LegalDocument build({String? description = 'Signed by both parties'}) {
    return LegalDocument(
      id: 'doc1',
      flatId: 'flat1',
      label: 'Lease Contract 2026',
      description: description,
      imagePath: '/data/app_flutter/LUCKY/legal_docs/abc.jpg',
      createdAt: createdAt,
    );
  }

  group('JSON', () {
    test('round-trips with a description', () {
      final original = build();
      final restored = LegalDocument.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.flatId, original.flatId);
      expect(restored.label, original.label);
      expect(restored.description, original.description);
      expect(restored.imagePath, original.imagePath);
      expect(restored.createdAt, original.createdAt);
    });

    test('round-trips without a description', () {
      final original = build(description: null);
      final json = original.toJson();
      expect(json['description'], isNull);

      final restored = LegalDocument.fromJson(json);
      expect(restored.description, isNull);
      expect(restored.label, original.label);
      expect(restored.imagePath, original.imagePath);
    });

    test('createdAt is stored as ISO-8601', () {
      expect(build().toJson()['createdAt'], '2026-03-04T10:30:00.000');
    });
  });

  group('copyWith', () {
    test('changes label and description, keeps image and id', () {
      final updated = build().copyWith(
        label: 'Lease Contract 2027',
        description: 'Renewed',
      );

      expect(updated.label, 'Lease Contract 2027');
      expect(updated.description, 'Renewed');
      expect(updated.id, 'doc1');
      expect(updated.flatId, 'flat1');
      expect(updated.imagePath, '/data/app_flutter/LUCKY/legal_docs/abc.jpg');
      expect(updated.createdAt, createdAt);
    });

    test('clearDescription drops the description', () {
      final cleared = build().copyWith(clearDescription: true);
      expect(cleared.description, isNull);
      expect(cleared.label, 'Lease Contract 2026');
    });

    test('passing a null description without clear keeps the old one', () {
      final kept = build().copyWith(label: 'New label');
      expect(kept.description, 'Signed by both parties');
    });
  });

  group('createNew', () {
    test('generates a non-empty id and a recent createdAt', () {
      final before = DateTime.now();
      final doc = LegalDocument.createNew(
        flatId: 'flat9',
        label: 'Utility Registration',
        description: 'DEWA',
        imagePath: '/tmp/x.jpg',
      );
      final after = DateTime.now();

      expect(doc.id, isNotEmpty);
      expect(doc.flatId, 'flat9');
      expect(doc.label, 'Utility Registration');
      expect(doc.description, 'DEWA');
      expect(doc.imagePath, '/tmp/x.jpg');
      expect(doc.createdAt.isBefore(before), isFalse);
      expect(doc.createdAt.isAfter(after), isFalse);
    });

    test('two documents never share an id', () {
      final a = LegalDocument.createNew(
        flatId: 'f',
        label: 'A',
        imagePath: '/a.jpg',
      );
      final b = LegalDocument.createNew(
        flatId: 'f',
        label: 'B',
        imagePath: '/b.jpg',
      );
      expect(a.id, isNot(b.id));
    });
  });
}
