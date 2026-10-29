import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/text_zoom/text_zoom.dart';

void main() {
  group('size', () {
    test('goes in steps from the smallest to the largest', () {
      expect(TextZoom.closestTo(114).percent, 110);
      expect(TextZoom.closestTo(116).percent, 120);
      expect(TextZoom.closestTo(10).percent, TextZoom.min);
      expect(TextZoom.closestTo(900).percent, TextZoom.max);
    });

    test('a step larger or smaller stops at the ends', () {
      expect(TextZoom.normal.larger.percent, 110);
      expect(TextZoom.normal.smaller.percent, 90);
      expect(TextZoom.closestTo(TextZoom.max).larger.percent, 200);
      expect(TextZoom.closestTo(TextZoom.min).smaller.percent, 80);
    });

    test('reads only the sizes there are', () {
      expect(TextZoom.fromJson(130)?.percent, 130);
      expect(TextZoom.fromJson(135), isNull);
      expect(TextZoom.fromJson(300), isNull);
      expect(TextZoom.fromJson('130'), isNull);
    });

    test('scales by its percent', () {
      expect(TextZoom.closestTo(150).factor, 1.5);
    });
  });
}
