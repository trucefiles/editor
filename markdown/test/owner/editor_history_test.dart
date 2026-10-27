import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart' show Picked, Replaced, Version;
import 'package:truce_markdown/src/owner/history/edit_history.dart';
import 'package:truce_markdown/truce_markdown.dart';

import 'editor_run.dart';

extension on EditorRun {
  void undo() => owner.send(Undo(revision: revision));
  void redo() => owner.send(Redo(revision: revision));

  /// What the file would hold now.
  String get text {
    pause();
    return edits.isEmpty ? '' : sent;
  }

  void editText(String text) => owner.send(EditText(text, revision: revision));

  String get markdown => (state.content as MarkdownContent).text;
}

void main() {
  group('steps', () {
    test('one per word typed', () {
      final run = EditorRun('')
        ..type('one')
        ..type(' ')
        ..type('two')
        ..undo();
      expect(run.rows, ['one ']);
      run.undo();
      expect(run.rows, ['']);
      expect(run.state.canUndo, isFalse);
    });

    test('a caret move starts a new one', () {
      final run = EditorRun('ab')
        ..caret(0, 2)
        ..type('x')
        ..caret(0, 0)
        ..type('y')
        ..undo();
      expect(run.rows, ['abx']);
    });

    test(
      'deleting after typing is a new one, and goes on while it deletes',
      () {
        final run = EditorRun('')
          ..type('abc')
          ..press(EditKey.backspace)
          ..press(EditKey.backspace)
          ..undo();
        expect(run.rows, ['abc']);
        run.undo();
        expect(run.rows, ['']);
      },
    );

    test('a caret moved away and back starts a new one', () {
      final run = EditorRun('ab')
        ..caret(0, 2)
        ..type('x')
        ..caret(0, 0)
        ..caret(0, 3)
        ..type('y')
        ..undo();
      expect(run.rows, ['abx']);
    });

    test('a divider deleted after deleting text is one of its own', () {
      final run = EditorRun('ab\n\n---\n\ncd')
        ..caret(2, 2)
        ..press(EditKey.backspace)
        ..caret(2, 0)
        ..press(EditKey.backspace)
        ..press(EditKey.backspace);
      expect(run.rows, ['ab', 'c']);
      final offered = run.outputs.whereType<UndoOffered>().single;
      expect(offered.what, OfferedUndo.removal);
      run.owner.send(UndoStep(offered.id));
      expect(run.rows, ['ab', '[DividerNode]', 'c']);
    });

    test('a quote ended by Backspace after deleting text is its own', () {
      final run = EditorRun('> ab')
        ..caret(0, 2)
        ..press(EditKey.backspace)
        ..press(EditKey.backspace)
        ..press(EditKey.backspace);
      expect(run.shown.view.doc.root.children.first, isNot(isA<QuoteNode>()));
      run.undo();
      expect(run.shown.view.doc.root.children.first, isA<QuoteNode>());
      expect(run.rows, ['']);
    });

    test('one per command, with the caret back where it was', () {
      final run = EditorRun('ab')
        ..caret(0, 1)
        ..press(EditKey.enter)
        ..undo();
      expect(run.rows, ['ab']);
      expect(run.shown.selection, TextSelection.caret(Place(run.leaf(0), 1)));
    });

    test('one for a box tap that also moves the item', () {
      final run = EditorRun('- [ ] a\n- [ ] b')..toggle(0);
      expect(run.text, '- [ ] b\n- [x] a');
      run.undo();
      expect(run.text, '- [ ] a\n- [ ] b');
      expect(run.state.canUndo, isFalse);
    });
  });

  group('undo and redo', () {
    test('write the text back byte for byte, untouched blocks as read', () {
      const opened = 'Title\r\n=====\r\n\r\n*  a\r\n*  b\r\n\r\nend  \r\n';
      final run = EditorRun(opened)
        ..caret(0, 5)
        ..type('!')
        ..press(EditKey.enter)
        ..type('x');
      expect(run.text, isNot(opened));
      run
        ..undo()
        ..undo()
        ..undo();
      expect(run.text, opened);
    });

    test('redo goes forward again, with the caret after the step', () {
      final run = EditorRun('')
        ..type('ab')
        ..undo()
        ..redo();
      expect(run.rows, ['ab']);
      expect(run.shown.selection, TextSelection.caret(Place(run.leaf(0), 2)));
      expect(run.state.canRedo, isFalse);
    });

    test('a new edit drops what redo had', () {
      final run = EditorRun('')
        ..type('ab')
        ..undo()
        ..type('c');
      expect(run.state.canRedo, isFalse);
    });

    test('go across a mode switch', () {
      final run = EditorRun('a')
        ..caret(0, 1)
        ..type('b')
        ..owner.send(const SetMode(EditMode.markdown))
        ..editText('abc');
      run.undo();
      expect(run.markdown, 'ab');
      run.undo();
      expect(run.markdown, 'a');
      expect((run.state.content as MarkdownContent).caret, 1);
      run
        ..owner.send(const SetMode(EditMode.visual))
        ..redo();
      expect(run.rows, ['ab']);
    });

    test('group typing in Markdown edit per word', () {
      final run = EditorRun('', mode: EditMode.markdown)
        ..editText('o')
        ..editText('on')
        ..editText('on ')
        ..editText('on x')
        ..undo();
      expect(run.markdown, 'on ');
    });

    test('a backup restored is one step, offered for undo', () {
      final run = EditorRun('mine')
        ..owner.send(ReplaceAll('backup', revision: 0));
      expect(run.rows, ['backup']);
      final offered = run.outputs.whereType<UndoOffered>().single;
      expect(offered.what, OfferedUndo.restore);
      run
        ..caret(0, 6)
        ..type('x')
        ..owner.send(UndoStep(offered.id));
      expect(run.outputs.last, isA<UndoRefused>());
      run
        ..undo()
        ..undo();
      expect(run.text, 'mine');
    });
  });

  group('the history', () {
    test('ends at a change from elsewhere', () {
      final run = EditorRun('a')..type('x');
      run.pause();
      run.owner.send(
        FromFile(Replaced('b', version: const Version(2), ackRev: 1)),
      );
      expect(run.state.canUndo, isFalse);
      run.undo();
      expect(
        run.outputs.last,
        isA<HistoryEnd>().having(
          (end) => end.start,
          'start',
          HistoryStart.changedElsewhere,
        ),
      );
      expect(run.rows, ['b']);
    });

    test('starts where it opened after a newer copy came before any edit', () {
      final run = EditorRun('a')
        ..owner.send(
          const FromFile(Replaced('b', version: Version(2), ackRev: 0)),
        )
        ..undo();
      expect((run.outputs.last as HistoryEnd).start, HistoryStart.opened);
    });

    test('ends at a version picked', () {
      final run = EditorRun('a')
        ..type('x')
        ..owner.send(const FromFile(Picked('b', version: Version(2), rev: 5)))
        ..undo();
      expect((run.outputs.last as HistoryEnd).start, HistoryStart.replacedHere);
    });

    test('tells when undo reaches the start', () {
      final run = EditorRun('')
        ..type('a')
        ..undo();
      expect((run.outputs.last as HistoryEnd).start, HistoryStart.opened);
    });

    test('keeps the latest steps only', () {
      final run = EditorRun('');
      for (var step = 0; step <= EditHistory.limit; step++) {
        run.press(EditKey.enter);
      }
      for (var step = 0; step < EditHistory.limit; step++) {
        run.undo();
      }
      expect(run.rows, hasLength(2));
      expect((run.outputs.last as HistoryEnd).start, HistoryStart.limit);
    });
  });
}
