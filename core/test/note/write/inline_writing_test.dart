import 'package:test/test.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/read/inline_reader.dart';
import 'package:truce_core/src/note/tree/blocks.dart';
import 'package:truce_core/src/note/tree/note_style.dart';
import 'package:truce_core/src/note/visible/formatting.dart';
import 'package:truce_core/src/note/visible/visible_text.dart';
import 'package:truce_core/src/note/write/inline/inline_writing.dart';

/// The inline source of the one paragraph of [markdown] after [edit].
String _written(String markdown, VisibleText Function(VisibleText) edit) {
  final leaf = NoteTree.read(markdown).leaves.single as TextLeaf;
  final old = visibleTextOf(leaf.text);
  final text = edit(old);
  final source = inlineSource(
    old: leaf.text.inlines,
    oldText: old,
    text: text,
    lines: TextLines.paragraph,
    style: const NoteStyle(),
    definitions: const {},
  )!;
  expect(
    visibleTextOf(readInlineText(source)).looksLike(text),
    isTrue,
    reason: source,
  );
  return source;
}

VisibleText Function(VisibleText) _insert(
  int at,
  String text, [
  Set<TextFormat>? formats,
]) =>
    (old) => old.replaced(
      at,
      at,
      VisibleText([
        TextPiece(
          text,
          formats == null
              ? (at > 0 ? old.formattingAt(at - 1) : Formatting.plain)
              : Formatting(formats),
        ),
      ]),
    );

/// The inline source of a paragraph whose text was replaced by [text].
String _typed(String text) => _written(
  'x',
  (old) => old.replaced(0, old.length, VisibleText([TextPiece(text)])),
);

VisibleText Function(VisibleText) _delete(int from, int to) =>
    (old) => old.replaced(from, to, VisibleText.empty);

VisibleText Function(VisibleText) _format(
  int from,
  int to,
  TextFormat format, {
  bool on = true,
}) =>
    (old) => old.reformatted(
      from,
      to,
      (formatting) => formatting.withFormat(format, on: on),
    );

void main() {
  group('a change to inline text', () {
    test('keeps untouched nodes as written', () {
      expect(
        _written('Fish &amp; chips', _insert(12, '!')),
        'Fish &amp; chips!',
      );
      expect(_written(r'cost 5\*3 now', _insert(12, '!')), r'cost 5\*3 now!');
    });

    test('types inside and beside spans as their format says', () {
      expect(_written('a **bold** c', _insert(4, 'x')), 'a **boxld** c');
      expect(_written('a **bold** c', _insert(6, 'x')), 'a **boldx** c');
      expect(_written('a **bold** c', _insert(6, 'x', {})), 'a **bold**x c');
      expect(_written('_a_ b', _insert(1, 'x')), '_ax_ b');
      expect(_written('[a](u) b', _insert(1, 'x')), '[ax](u) b');
    });

    test('writes new spans in the note style, inside words with `*`', () {
      expect(_written('abc', _format(1, 2, TextFormat.strong)), 'a**b**c');
      expect(_written('a b c', _format(2, 3, TextFormat.emphasis)), 'a *b* c');
      expect(_written('abc', _format(0, 3, TextFormat.code)), '`abc`');
    });

    test('splits and joins spans', () {
      expect(
        _written('**ab**', _format(0, 1, TextFormat.strong, on: false)),
        'a**b**',
      );
      expect(_written('**a**x**b**', _delete(1, 2)), '**ab**');
    });

    test('escapes only what would read as syntax', () {
      expect(_typed('*word*'), r'\*word\*');
      expect(_typed('5 * 3'), '5 * 3');
      expect(_typed('snake_case_name'), 'snake_case_name');
      expect(_typed('&amp;'), r'\&amp;');
      expect(_typed('# x'), r'\# x');
      expect(_typed('1. x'), r'1\. x');
      expect(_typed(' x'), '&#32;x');
      expect(
        _written(
          'x',
          (_) =>
              VisibleText([TextPiece('a'), HardBreakPiece(), TextPiece(' b')]),
        ),
        'a\\\n&#32;b',
      );
      expect(_typed('[a](b)'), r'\[a\]\(b\)');
    });
  });
}
