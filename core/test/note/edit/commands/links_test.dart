import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/commands/command.dart';
import 'package:truce_core/src/note/edit/commands/links.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/note_tree.dart';

ShownNote _note(String text) => ShownNote(NoteTree.read(text));

Place _at(ShownNote note, int offset) =>
    Place((note.rows.first as TextRow).slot, offset);

/// [text] after the link dialog sets [shows] linking [url] over [from]
/// to [to] of its first row; with the caret after.
(String, Selection) _linked(
  String text,
  int from,
  int to,
  String shows,
  String url,
) {
  final note = _note(text);
  final edited = run(
    note,
    SetLink(TextSelection(_at(note, from), _at(note, to)), shows, url),
  );
  return (edited.note.tree.text, edited.selection);
}

String _unlinked(String text, int offset) {
  final note = _note(text);
  return run(note, RemoveLink(_at(note, offset))).note.tree.text;
}

void main() {
  group('setting a link', () {
    test('links the selected text, keeping its formats', () {
      expect(_linked('a **b** c', 2, 3, 'b', 'u').$1, 'a **[b](u)** c');
    });

    test('puts in new text, or the url if none, the caret after it', () {
      final (text, selection) = _linked('a b', 2, 2, 'site', 'u');
      expect(text, 'a [site](u)b');
      expect((selection as TextSelection).extent.offset, 6);
      expect(_linked('a b', 2, 3, '', 'u').$1, 'a [u](u)');
    });

    test('keeps a link\'s spelling when its url stays', () {
      expect(
        _linked('[a][r]\n\n[r]: u', 0, 1, 'b', 'u').$1,
        '[b][r]\n\n[r]: u',
      );
    });

    test('changes a link\'s url', () {
      expect(_linked('[a](u)', 0, 1, 'a', 'v').$1, '[a](v)');
    });
  });

  group('removing a link', () {
    test('keeps its text', () {
      expect(_unlinked('x [a **b**](u) y', 3), 'x a **b** y');
      expect(_unlinked('x [ab](u) y', 4), 'x ab y');
    });

    test('is possible on a link, not on text GFM reads as one', () {
      final note = _note('[a](u) www.example.com');
      expect(canRemoveLink(note, _at(note, 0)), isTrue);
      expect(canRemoveLink(note, _at(note, 3)), isFalse);
      expect(canRemoveLink(note, _at(note, 8)), isFalse);
    });
  });
}
