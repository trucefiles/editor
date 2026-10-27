import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/first_mode.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

void main() {
  group('a document first shows', () {
    test('in Visual edit if it has checkboxes', () {
      expect(firstMode(hasCheckboxes: true, typing: false), EditMode.visual);
      expect(firstMode(hasCheckboxes: true, typing: true), EditMode.visual);
    });

    test('in Read without checkboxes', () {
      expect(firstMode(hasCheckboxes: false, typing: false), EditMode.read);
    });

    test('in Visual edit to type a new document in', () {
      expect(firstMode(hasCheckboxes: false, typing: true), EditMode.visual);
    });
  });
}
