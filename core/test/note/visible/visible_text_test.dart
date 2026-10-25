import 'package:test/test.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/tree/blocks.dart';
import 'package:truce_core/src/note/visible/formatting.dart';
import 'package:truce_core/src/note/visible/visible_text.dart';

VisibleText _visible(String markdown) => visibleTextOf(
  (NoteTree.read(markdown).leaves.single as TextLeaf).text,
);

void main() {
  group('visible text', () {
    test('shows text without marks, escapes or references', () {
      expect(
        _visible(r'**bold** _it_ ~~gone~~ `code` 5\*3 &amp;').text,
        'bold it gone code 5*3 &',
      );
    });

    test('formats each character as its spans say', () {
      final text = _visible('a **b _c_** d');
      expect(text.formattingAt(0), Formatting.plain);
      expect(text.formattingAt(2).formats, {TextFormat.strong});
      expect(text.formattingAt(4).formats, {
        TextFormat.strong,
        TextFormat.emphasis,
      });
      expect(text.formattingAt(6), Formatting.plain);
    });

    test('shows a soft break as a space, a hard break as a break', () {
      expect(_visible('a\nb').text, 'a b');
      expect(_visible('a\\\nb').text, 'a\nb');
      expect(_visible('a  \nb').text, 'a\nb');
    });

    test('shows images and inline HTML as one character each', () {
      expect(
        _visible('a ![alt](x.png) <kbd>b</kbd>').text,
        'a $objectCharacter ${objectCharacter}b$objectCharacter',
      );
    });

    test('marks one link with one mark, also bare ones', () {
      final text = _visible('[a *b*](u) and www.x.org');
      expect(text.formattingAt(0).link, same(text.formattingAt(2).link));
      expect(text.formattingAt(0).link!.destination, 'u');
      expect(text.formattingAt(8).link!.destination, 'http://www.x.org');
    });

    test('slices and replaces by character', () {
      final text = _visible('ab **cd** ef');
      expect(text.slice(1, 4).text, 'b c');
      expect(text.slice(3, 5).formattingAt(0).formats, {TextFormat.strong});
      final replaced = text.replaced(1, 6, VisibleText([TextPiece('X')]));
      expect(replaced.text, 'aXef');
      expect(replaced.pieces, hasLength(1));
    });

    test('reformats a range', () {
      final text = _visible('abc').reformatted(
        1,
        2,
        (formatting) => formatting.withFormat(TextFormat.code, on: true),
      );
      expect(text.pieces, hasLength(3));
      expect(text.formattingAt(1).formats, {TextFormat.code});
    });
  });
}
