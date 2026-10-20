import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/note_mode.dart';

void main() {
  group('a note first shows', () {
    test('in Visual edit if it has checkboxes', () {
      expect(
        NoteMode.first(hasCheckboxes: true, typing: false),
        NoteMode.visual,
      );
      expect(
        NoteMode.first(hasCheckboxes: true, typing: true),
        NoteMode.visual,
      );
    });

    test('in Read without checkboxes', () {
      expect(
        NoteMode.first(hasCheckboxes: false, typing: false),
        NoteMode.read,
      );
    });

    test('in Visual edit to type a new note in', () {
      expect(
        NoteMode.first(hasCheckboxes: false, typing: true),
        NoteMode.visual,
      );
    });
  });

  test('each mode shows marks in its style', () {
    expect(NoteMode.visual.marks, MarkStyle.mixed);
    expect(NoteMode.markdown.marks, MarkStyle.shown);
    expect(NoteMode.read.marks, MarkStyle.hidden);
  });

  test('only Markdown edit shows list items and quotes as their lines', () {
    expect(
      [for (final mode in NoteMode.values) mode.showsBlocks],
      [true, false, true],
    );
  });
}
