import 'package:flutter_test/flutter_test.dart';
import 'package:lucky/theme/flat_color.dart';

void main() {
  group('flatColorFor', () {
    test('returns the same color on repeated calls for the same id', () {
      const ids = ['flat-1', 'apartment-b', 'x', 'F-42'];
      for (final id in ids) {
        final first = flatColorFor(id);
        final second = flatColorFor(id);
        expect(first, second);
      }
    });

    test('known ids map to distinct colors from the 8-hue palette', () {
      const ids = [
        'flat-1',
        'flat-2',
        'flat-3',
        'flat-4',
        'flat-5',
        'flat-6',
        'flat-7',
        'flat-8',
      ];
      final colors = ids.map(flatColorFor).toSet();
      expect(colors, hasLength(8));
      expect(flatPalette, hasLength(8));
      for (final color in colors) {
        expect(flatPalette, contains(color));
      }
    });

    test('always resolves into the palette, never outside it', () {
      for (var i = 0; i < 200; i++) {
        expect(flatPalette, contains(flatColorFor('generated-$i')));
      }
    });
  });
}