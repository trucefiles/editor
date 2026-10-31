import 'package:test/test.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/keys/key_map.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/view/rows.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

import '../support/shown.dart';

Shown _document(String text, {DoneSections? done}) =>
    Shown.read(text, done: done);

/// The caret at [offset] in row [row] of [document].
TextSelection _caret(Shown document, int row, int offset) =>
    document.caret(row, offset);

KeyAction _action(
  String text,
  int row,
  int offset,
  EditKey key, {
  DoneSections? done,
}) {
  final document = _document(text, done: done);
  return keyAction(document.view, _caret(document, row, offset), key);
}

/// [text] after [key] at [offset] in its row [row].
String _pressed(String text, int row, int offset, EditKey key) {
  final document = _document(text);
  final action = keyAction(document.view, _caret(document, row, offset), key);
  return document.run((action as RunCommand).command).document.text;
}

Command _command(KeyAction action) => (action as RunCommand).command;

void main() {
  group('Enter', () {
    test('splits text', () {
      expect(_pressed('ab', 0, 1, EditKey.enter), 'a\n\nb');
      expect(_pressed('- ab', 0, 1, EditKey.enter), '- a\n- b');
    });

    test('in an empty item goes one level out', () {
      final document = _document('- a\n  - b');
      final split = document.run(SplitBlock(_caret(document, 1, 1))).document;
      expect(
        _command(keyAction(split.view, _caret(split, 2, 0), EditKey.enter)),
        isA<Outdent>(),
      );
      expect(_pressed('-\n- a', 0, 0, EditKey.enter), '- a');
    });

    test('in an empty paragraph in a quote goes out of it', () {
      final document = _document('> a');
      final split = document.run(SplitBlock(_caret(document, 0, 1))).document;
      expect(
        _command(keyAction(split.view, _caret(split, 1, 0), EditKey.enter)),
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

    test('after a rule removes it, as one character; after a table opens '
        'it', () {
      expect(_pressed('a\n\n---\n\nb', 2, 0, EditKey.backspace), 'a\n\nb');
      expect(
        _action('| a |\n| - |\n\nb', 1, 0, EditKey.backspace),
        isA<OpenRaw>().having((it) => it.atEnd, 'at end', isTrue),
      );
    });

    test('after a rule keeps the caret where it was', () {
      final document = _document('a\n\n---\n\nb');
      final caret = _caret(document, 2, 0);
      final action = keyAction(document.view, caret, EditKey.backspace);
      final edited = document.run(_command(action));
      expect(edited.selection, edited.document.caret(1, 0));
    });

    test("in an item's line below its separator removes the separator; the "
        'item keeps its box', () {
      expect(
        _pressed('- [ ] a\n- [ ] ***\n  b', 2, 0, EditKey.backspace),
        '- [ ] a\n- [ ] b',
      );
    });

    test('at the start of code does nothing unless it is empty', () {
      expect(
        _action('a\n\n```\nb\n```', 1, 0, EditKey.backspace),
        isA<Consumed>(),
      );
      expect(_pressed('a\n\n```\n```', 1, 0, EditKey.backspace), 'a');
    });

    test('at the document\'s start does nothing', () {
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

    test('right after Enter in a Done section joins the split back', () {
      final done = DoneSections();
      final text = '- [ ] c\n- [x] ab';
      final document = _document(text, done: done);
      ({Shown document, Selection selection}) press(
        Shown document,
        Selection at,
        EditKey key,
      ) => document.run(_command(keyAction(document.view, at, key)));
      final split = press(document, _caret(document, 1, 1), EditKey.enter);
      expect(split.document.text, '- [ ] c\n- [x] a\n- [x] b');
      final joined = press(split.document, split.selection, EditKey.backspace);
      expect(joined.document.text, text);
    });

    test('on a selected rule removes it, Backspace backward, Delete '
        'forward', () {
      final document = _document('a\n\n---');
      final rule = document.doc.root.children.last.id;
      expect(
        _command(
          keyAction(document.view, BlockSelection(rule), EditKey.backspace),
        ),
        isA<RemoveBlock>().having((it) => it.backward, 'backward', isTrue),
      );
      expect(
        _command(
          keyAction(document.view, BlockSelection(rule), EditKey.delete),
        ),
        isA<RemoveBlock>().having((it) => it.backward, 'backward', isFalse),
      );
    });

    test('over a selection deletes it', () {
      final document = _document('abc');
      final range = TextSelection(
        _caret(document, 0, 0).base,
        _caret(document, 0, 2).base,
      );
      expect(
        _command(keyAction(document.view, range, EditKey.backspace)),
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

    test('before a rule removes it, as one character, the caret staying', () {
      final document = _document('a\n\n---\n\nb');
      final action = keyAction(
        document.view,
        _caret(document, 0, 1),
        EditKey.delete,
      );
      final edited = document.run(_command(action));
      expect(edited.document.text, 'a\n\nb');
      expect(edited.selection, edited.document.caret(0, 1));
    });

    test('before a separator item leaves that item empty', () {
      expect(
        _pressed('- [ ] a\n- [ ] ***\n- [ ] b', 0, 1, EditKey.delete),
        '- [ ] a\n- [ ] \n- [ ] b',
      );
    });

    test('at the document\'s end does nothing', () {
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
      final document = _document('a\n\n```\nb\n```');
      final across = TextSelection(
        _caret(document, 0, 0).base,
        _caret(document, 1, 1).base,
      );
      expect(keyAction(document.view, across, EditKey.tab), isA<Consumed>());
    });
  });

  group('shortcuts', () {
    test('style a selection, or the typing style at a caret', () {
      final document = _document('ab');
      final range = TextSelection(
        _caret(document, 0, 0).base,
        _caret(document, 0, 2).base,
      );
      expect(
        _command(keyAction(document.view, range, EditKey.bold)),
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

    test('open no link dialog over several text places', () {
      final document = _document('ab\n\ncd');
      final range = TextSelection(document.place(0, 1), document.place(1, 1));
      expect(keyAction(document.view, range, EditKey.link), isA<Consumed>());
    });
  });

  test('Enter on a selected divider adds a line after it', () {
    final document = _document('a\n\n---');
    final divider = document.view.rows.whereType<BlockRow>().first.leaf;
    expect(
      _command(
        keyAction(document.view, BlockSelection(divider.id), EditKey.enter),
      ),
      isA<LineAfter>(),
    );
  });
}
