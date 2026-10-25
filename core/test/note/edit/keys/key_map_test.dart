import 'package:test/test.dart';
import 'package:truce_core/src/note/edit/commands/command.dart';
import 'package:truce_core/src/note/edit/keys/key_map.dart';
import 'package:truce_core/src/note/edit/shown/rows.dart';
import 'package:truce_core/src/note/edit/shown/selection.dart';
import 'package:truce_core/src/note/edit/shown/shown_note.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/visible/formatting.dart';

ShownNote _note(String text, {DoneSections? done}) =>
    ShownNote(NoteTree.read(text), done: done);

/// The caret at [offset] in text row [row] of [note].
TextSelection _caret(ShownNote note, int row, int offset) =>
    TextSelection.caret(Place((note.rows[row] as TextRow).slot, offset));

KeyAction _action(
  String text,
  int row,
  int offset,
  EditKey key, {
  DoneSections? done,
}) {
  final note = _note(text, done: done);
  return keyAction(note, _caret(note, row, offset), key);
}

/// [text] after [key] at [offset] in its row [row].
String _pressed(String text, int row, int offset, EditKey key) {
  final note = _note(text);
  final action = keyAction(note, _caret(note, row, offset), key);
  return run(note, (action as RunCommand).command).note.tree.text;
}

Command _command(KeyAction action) => (action as RunCommand).command;

void main() {
  group('Enter', () {
    test('splits text', () {
      expect(_pressed('ab', 0, 1, EditKey.enter), 'a\n\nb');
      expect(_pressed('- ab', 0, 1, EditKey.enter), '- a\n- b');
    });

    test('in an empty item goes one level out', () {
      final note = _note('- a\n  - b');
      final split = run(note, SplitBlock(_caret(note, 1, 1))).note;
      expect(
        _command(keyAction(split, _caret(split, 2, 0), EditKey.enter)),
        isA<Outdent>(),
      );
      expect(_pressed('-\n- a', 0, 0, EditKey.enter), '- a');
    });

    test('in an empty paragraph in a quote goes out of it', () {
      final note = _note('> a');
      final split = run(note, SplitBlock(_caret(note, 0, 1))).note;
      expect(
        _command(keyAction(split, _caret(split, 1, 0), EditKey.enter)),
        isA<RemoveFrame>(),
      );
    });

    test('in a Done section splits the item', () {
      expect(
        _command(
          _action('- [x] a\n-', 1, 0, EditKey.enter, done: DoneSections()),
        ),
        isA<SplitBlock>(),
      );
    });
  });

  test('Shift+Enter is a line break, in code a new line', () {
    expect(_pressed('ab', 0, 1, EditKey.shiftEnter), 'a\\\nb');
    expect(
      _pressed('```\nab\n```', 0, 1, EditKey.shiftEnter),
      '```\na\nb\n```',
    );
  });

  group('Backspace', () {
    test('deletes the character before, whole', () {
      expect(_pressed('a👍🏽b', 0, 5, EditKey.backspace), 'ab');
    });

    test('at the first text of an item or quote takes that frame off', () {
      expect(_pressed('- a', 0, 0, EditKey.backspace), 'a');
      expect(_pressed('> a', 0, 0, EditKey.backspace), 'a');
    });

    test('at a text\'s start otherwise joins it to the text above', () {
      expect(_pressed('a\n\nb', 1, 0, EditKey.backspace), 'ab');
    });

    test('after a rule selects it; after a table opens it', () {
      final rule = _note('---\n\na');
      expect(
        keyAction(rule, _caret(rule, 1, 0), EditKey.backspace),
        isA<SelectBlock>().having(
          (it) => it.block,
          'block',
          rule.tree.root.children.first.id,
        ),
      );
      expect(
        _action('| a |\n| - |\n\nb', 1, 0, EditKey.backspace),
        isA<OpenRaw>().having((it) => it.atEnd, 'at end', isTrue),
      );
    });

    test('at the start of code does nothing unless it is empty', () {
      expect(
        _action('a\n\n```\nb\n```', 1, 0, EditKey.backspace),
        isA<Consumed>(),
      );
      expect(_pressed('a\n\n```\n```', 1, 0, EditKey.backspace), 'a');
    });

    test('at the note\'s start does nothing', () {
      expect(_action('a', 0, 0, EditKey.backspace), isA<Consumed>());
    });

    test('joins only within a Done section', () {
      final done = DoneSections();
      expect(
        _action('- [x] a\n- b', 1, 0, EditKey.backspace, done: done),
        isA<Consumed>(),
      );
      expect(
        _command(
          _action('- [x] a\n- [x] b', 1, 0, EditKey.backspace, done: done),
        ),
        isA<JoinWithPrevious>(),
      );
    });

    test('on a selected rule removes it', () {
      final note = _note('a\n\n---');
      final rule = note.tree.root.children.last.id;
      expect(
        _command(keyAction(note, BlockSelection(rule), EditKey.backspace)),
        isA<RemoveBlock>(),
      );
    });

    test('over a selection deletes it', () {
      final note = _note('abc');
      final range = TextSelection(
        _caret(note, 0, 0).base,
        _caret(note, 0, 2).base,
      );
      expect(
        _command(keyAction(note, range, EditKey.backspace)),
        isA<DeleteRange>(),
      );
    });
  });

  group('Delete', () {
    test('deletes the character after', () {
      expect(_pressed('abc', 0, 1, EditKey.delete), 'ac');
    });

    test('at a text\'s end joins the text below', () {
      expect(_pressed('a\n\nb', 0, 1, EditKey.delete), 'ab');
    });

    test('before a rule selects it', () {
      expect(_action('a\n\n---', 0, 1, EditKey.delete), isA<SelectBlock>());
    });

    test('at the note\'s end does nothing', () {
      expect(_action('a', 0, 1, EditKey.delete), isA<Consumed>());
    });
  });

  group('Tab', () {
    test('indents and outdents items where possible', () {
      expect(_pressed('- a\n- b', 1, 0, EditKey.tab), '- a\n  - b');
      expect(_action('- a', 0, 0, EditKey.tab), isA<Consumed>());
      expect(_pressed('- a\n  - b', 1, 0, EditKey.shiftTab), '- a\n- b');
    });

    test('is a tab in code, and nothing elsewhere', () {
      expect(_pressed('```\nab\n```', 0, 1, EditKey.tab), '```\na\tb\n```');
      expect(_action('a', 0, 0, EditKey.tab), isA<Consumed>());
    });
  });

  group('shortcuts', () {
    test('style a selection, or the typing style at a caret', () {
      final note = _note('ab');
      final range = TextSelection(
        _caret(note, 0, 0).base,
        _caret(note, 0, 2).base,
      );
      expect(
        _command(keyAction(note, range, EditKey.bold)),
        isA<ToggleStyle>(),
      );
      expect(
        _action('ab', 0, 1, EditKey.italic),
        isA<ToggleTypingStyle>().having(
          (it) => it.format,
          'format',
          TextFormat.emphasis,
        ),
      );
    });

    test('set frames and open the link dialog', () {
      expect(
        _command(_action('a', 0, 0, EditKey.checklist)),
        isA<SetFrame>().having((it) => it.kind, 'kind', FrameKind.checkbox),
      );
      expect(_action('a', 0, 0, EditKey.link), isA<OpenLinkDialog>());
    });
  });
}
