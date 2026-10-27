import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart'
    show
        Edited,
        FileOutput,
        Found,
        Moment,
        Observed,
        Picked,
        Replaced,
        SaveNow,
        Secure,
        SecureReason,
        Seen,
        ToEditor,
        Version,
        openedFileOwner;
import 'package:truce_markdown/truce_markdown.dart';

import 'editor_run.dart';

void main() {
  group('typing', () {
    test('changes what shows at once, and sends the text at a pause', () {
      final run = EditorRun('ab')
        ..caret(0, 1)
        ..type('x');
      expect(run.rows, ['axb']);
      expect(run.edits, isEmpty);
      expect(run.state.unsent, isTrue);
      run.pause();
      expect(
        (run.sent, run.edits.single.rev, run.edits.single.lineage),
        ('axb', 1, v1),
      );
      expect(run.state.unsent, isFalse);
    });

    test('sends at most every 30 s while it goes on', () {
      final run = EditorRun('ab')
        ..type('x')
        ..type('y');
      run.fire(SaveTimer.long);
      expect(run.sent, 'xyab');
      run.type('z');
      run.pause();
      expect(run.edits.map((edit) => edit.rev), [2, 3]);
    });

    test('writes into the folder 30 s after a pause', () {
      final run = EditorRun('ab')
        ..type('x')
        ..pause();
      run.fire(SaveTimer.folder);
      expect(
        run.outputs.last,
        isA<ToFile>().having((out) => out.input, 'input', isA<SaveNow>()),
      );
    });

    test('takes the typing style set at the caret, until the caret moves', () {
      final run = EditorRun('ab')
        ..caret(0, 1)
        ..press(EditKey.bold)
        ..type('x');
      run.pause();
      expect(run.sent, 'a**x**b');
      run
        ..caret(0, 0)
        ..type('y')
        ..pause();
      expect(run.sent, 'ya**x**b');
    });

    test('typed where a selection was deleted, takes its style', () {
      final run = EditorRun('a **bc** d');
      final leaf = run.leaf(0);
      run
        ..runCommand(DeleteRange(TextSelection(Place(leaf, 2), Place(leaf, 4))))
        ..type('x')
        ..pause();
      expect(run.sent, 'a **x** d');
    });

    test('typed over another place, takes the style there', () {
      final run = EditorRun('a **b**')
        ..caret(0, 1)
        ..press(EditKey.bold);
      final b = Place(run.leaf(0), 2);
      run.owner.send(
        Typed('x', over: TextSelection.caret(b), revision: run.revision),
      );
      run.pause();
      expect(run.sent, 'a x**b**');
    });

    test('typed text with line breaks splits as a paste', () {
      final run = EditorRun('- a')
        ..caret(0, 1)
        ..type('x\ny')
        ..pause();
      expect(run.rows, ['ax', 'y']);
      expect(run.sent, '- ax\n- y');
    });

    test('a selected divider stays selected through a change elsewhere', () {
      final run = EditorRun('a\n\n---\n\nb')
        ..caret(2, 0)
        ..press(EditKey.backspace);
      run.owner.send(
        const FromFile(Replaced('x\n\na\n\n---\n\nb', version: v2, ackRev: 0)),
      );
      expect(run.shown.selection, BlockSelection(run.leaf(2)));
    });

    test('drops an input on what no longer shows', () {
      final run = EditorRun('- [ ] a\n- [ ] b');
      final tapped = run.revision;
      run.owner.send(
        const FromFile(Replaced('- [ ] a\n- [ ] c', version: v2, ackRev: 0)),
      );
      final shown = run.state;
      run.owner.send(ToggleItems([run.item(0)], revision: tapped));
      expect(run.state, same(shown));
      expect(run.edits, isEmpty);
    });

    test('a timer firing leaves what shows as it was', () {
      final run = EditorRun('ab')..type('x');
      final revision = run.revision;
      run.pause();
      expect(run.revision, revision);
    });

    test('a change printing the same text is still sent, with its rev', () {
      final run = EditorRun('ab')
        ..caret(0, 2)
        ..type(' ')
        ..pause();
      expect((run.sent, run.edits.single.rev), ('ab', 1));
    });
  });

  group('Markdown edit', () {
    test('edits the printed text, sent by the same timing', () {
      final run = EditorRun('a\n\nb', mode: EditMode.markdown);
      run.owner.send(EditText('a\n\n- b', revision: run.revision));
      run.pause();
      expect(run.sent, 'a\n\n- b');
    });

    test('switching to Read sends the edits, so they are what shows', () {
      final run = EditorRun('a');
      run.type('x');
      expect(run.edits, isEmpty);

      run.owner.send(const SetMode(EditMode.read));

      expect(run.sent, 'xa');
    });

    test('takes over Visual edit\'s text, and gives it back read anew', () {
      final run = EditorRun('a\n\nb')
        ..caret(1, 1)
        ..type('c');
      run.owner.send(const SetMode(EditMode.markdown));
      expect(
        run.state.content,
        isA<MarkdownContent>().having(
          (content) => content.text,
          'text',
          'a\n\nbc',
        ),
      );
      run.owner
        ..send(EditText('a\n\nbc\n\nd', revision: run.revision))
        ..send(const SetMode(EditMode.visual));
      expect(run.rows, ['a', 'bc', 'd']);
      expect(run.shown.selection, TextSelection.caret(Place(run.leaf(1), 2)));
    });
  });

  group('changes from the file owner', () {
    test('a change elsewhere shows, the caret kept by its lines', () {
      final run = EditorRun('ab\n\ncd')..caret(1, 1);
      run.owner.send(
        const FromFile(Replaced('ab\n\ncd!', version: v2, ackRev: 0)),
      );
      expect(run.rows, ['ab', 'cd!']);
      // Its line changed: the caret goes to the kept line before it.
      expect(run.shown.selection, TextSelection.caret(Place(run.leaf(0), 1)));
      expect(run.edits, isEmpty);
      run
        ..type('x')
        ..pause();
      expect(run.edits.single.lineage, v2);
    });

    test('a caret on a kept line stays there', () {
      final run = EditorRun('ab\n\ncd\n\nef')..caret(2, 1);
      run.owner.send(
        const FromFile(Replaced('ab\n\nef', version: v2, ackRev: 0)),
      );
      expect(run.shown.selection, TextSelection.caret(Place(run.leaf(1), 1)));
    });

    test('a change elsewhere after an edit not sent there is ignored', () {
      final run = EditorRun('ab')..type('x');
      run.owner.send(const FromFile(Replaced('z', version: v2, ackRev: 0)));
      expect(run.rows, ['xab']);
      run.pause();
      expect(run.edits.last.lineage, v1);
    });

    test('a pick always shows, and later edits descend from it', () {
      final run = EditorRun('ab')..type('x');
      // The file owner never got the edit at rev 1: revs go on from 0.
      run.owner.send(const FromFile(Picked('z', version: v2, rev: 0)));
      expect(run.rows, ['z']);
      expect(run.state.unsent, isFalse);
      run
        ..type('y')
        ..pause();
      expect(
        (run.edits.last.lineage, run.edits.last.rev, run.edits.last.picks),
        (v2, 1, 1),
      );
    });
  });

  group('checked items', () {
    test('with "Move to end" a checked item moves', () {
      final run = EditorRun('- [ ] a\n- [ ] b')
        ..caret(1, 0)
        ..toggle(0)
        ..pause();
      expect(run.sent, '- [ ] b\n- [x] a');
    });

    test('checked together move together, in their order; an unchecked '
        'one stays where it is', () {
      final run = EditorRun('- [ ] a\n- [ ] b\n- [x] c\n- [ ] d');
      run.owner.send(
        ToggleItems([
          run.item(1),
          run.item(0),
          run.item(2),
        ], revision: run.revision),
      );
      run.pause();
      expect(run.sent, '- [ ] c\n- [ ] d\n- [x] a\n- [x] b');
    });

    test('with "Move to end" an item added last goes above the checked '
        'ones; in place, at the end', () {
      String added(CheckedItems checkedItems) {
        final run = EditorRun('- [ ] a\n- [x] b', checkedItems: checkedItems);
        run
          ..runCommand(AddItem(run.shown.view.doc.root.children.single.id))
          ..type('new')
          ..pause();
        return run.sent;
      }

      expect(added(CheckedItems.moveToEnd), '- [ ] a\n- [ ] new\n- [x] b');
      expect(added(CheckedItems.inPlace), '- [ ] a\n- [x] b\n- [ ] new');
    });

    test('in Read, the menu commands run and the text is sent at once', () {
      final run = EditorRun('- [x] a\n- [ ] b', mode: EditMode.read);
      run.runCommand(MoveToEnd(run.shown.selection));
      expect(run.sent, '- [ ] b\n- [x] a');
      run.runCommand(ClearChecked(run.shown.selection));
      expect(run.sent, '- [ ] b');
      run.runCommand(Toggle(run.item(0), run.shown.selection));
      expect(run.sent, '- [ ] b', reason: 'Read takes no edits');
    });

    test('in place stay where they are', () {
      final run =
          EditorRun('- [ ] a\n- [ ] b', checkedItems: CheckedItems.inPlace)
            ..toggle(0)
            ..pause();
      expect(run.sent, '- [x] a\n- [ ] b');
    });

    test('in a Done section show there, the file in place', () {
      final run =
          EditorRun('- [ ] a\n- [ ] b', checkedItems: CheckedItems.doneSection)
            ..toggle(0)
            ..pause();
      expect(run.shown.view.rows.last.done, isTrue);
      expect(run.sent, '- [x] a\n- [ ] b');
    });

    test('collapsed in a Done section stay so through a change elsewhere '
        'and Markdown edit', () {
      final run = EditorRun(
        '- [ ] a\n- [x] b',
        checkedItems: CheckedItems.doneSection,
      );
      final list = run.shown.view.doc.root.children.first.id;
      run.owner.send(SetCollapsed(list, collapsed: true));
      expect(run.rows, ['a']);
      run.owner.send(
        const FromFile(
          Replaced('x\n\n- [ ] a\n- [x] b', version: v2, ackRev: 0),
        ),
      );
      expect(run.rows, ['x', 'a']);
      run.owner
        ..send(const SetMode(EditMode.markdown))
        ..send(EditText('y\n\n- [ ] a\n- [x] b', revision: run.revision))
        ..send(const SetMode(EditMode.visual));
      expect(run.rows, ['y', 'a']);
    });

    test('are toggled by a box tap only, never a Toggle command', () {
      final run = EditorRun('- [ ] a');
      expect(
        () => run.runCommand(Toggle(run.item(0), run.shown.selection)),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('removals', () {
    test('can be undone while the text did not change since', () {
      final run = EditorRun('- a\n- b');
      run.runCommand(DeleteItem(run.item(0)));
      final removed = run.outputs.whereType<ItemsRemoved>().single;
      run.owner.send(UndoStep(removed.id));
      run.pause();
      expect(run.sent, '- a\n- b');
    });

    test('of one code block are offered, of an emptied one not', () {
      final run = EditorRun('a\n\n```\nx\n```\n\nb');
      run.runCommand(
        DeleteRange(
          TextSelection(Place(run.leaf(0), 1), Place(run.leaf(1), 1)),
        ),
      );
      expect(run.rows, ['a', 'b']);
      expect(run.outputs.whereType<ItemsRemoved>(), hasLength(1));
      final emptied = EditorRun('a\n\n```\n```\n\nb');
      emptied.runCommand(JoinWithPrevious(Place(emptied.leaf(1), 0)));
      expect(emptied.rows, ['a', 'b']);
      expect(emptied.outputs.whereType<ItemsRemoved>(), isEmpty);
    });

    test('cannot be undone after another edit', () {
      final run = EditorRun('- a\n- b');
      run.runCommand(DeleteItem(run.item(0)));
      final removed = run.outputs.whereType<ItemsRemoved>().single;
      run
        ..caret(0, 0)
        ..type('x')
        ..owner.send(UndoStep(removed.id));
      expect(run.outputs.last, isA<UndoRefused>());
      expect(run.rows, ['xb']);
    });
  });

  group('a raw block', () {
    test('opens on a tap, edits as text, and reads anew once left', () {
      final run = EditorRun('a\n\n<div>\nx\n</div>\n\nb');
      run.owner.send(
        OpenRawBlock(run.leaf(1), atEnd: false, revision: run.revision),
      );
      run.owner.send(
        EditRaw('# T', base: 3, extent: 3, revision: run.revision),
      );
      run.pause();
      expect(run.sent, 'a\n\n# T\n\nb');
      expect(run.rows, ['a', '[RawNode]', 'b']);
      run.caret(0, 0);
      expect(run.shown.raw, isNull);
      expect(run.rows, ['a', 'T', 'b']);
    });

    test('opens by Backspace after it', () {
      final run = EditorRun('a\n\n<!-- c -->\n\nb')..caret(2, 0);
      run.press(EditKey.backspace);
      expect(run.shown.raw?.text, '<!-- c -->');
    });

    test('closes before a box tap, which then toggles', () {
      final run = EditorRun('- [ ] a\n\n<div>\n\nb');
      run.owner
        ..send(OpenRawBlock(run.leaf(1), atEnd: true, revision: run.revision))
        ..send(EditRaw('<p>', base: 3, extent: 3, revision: run.revision));
      run.toggle(0);
      expect(run.shown.raw, isNull);
      run.pause();
      expect(run.sent, '- [x] a\n\n<p>\n\nb');
    });

    test('closes before typing, which then goes where the caret was', () {
      final run = EditorRun('ab\n\n<div>')..caret(0, 2);
      run.owner.send(
        OpenRawBlock(run.leaf(1), atEnd: true, revision: run.revision),
      );
      run.type('c');
      expect(run.shown.raw, isNull);
      expect(run.rows, ['abc', '[RawNode]', '']);
    });

    test('closes before another raw block opens', () {
      final run = EditorRun('<div>\n\na\n\n<p>');
      run.owner
        ..send(OpenRawBlock(run.leaf(0), atEnd: true, revision: run.revision))
        ..send(EditRaw('<nav>', base: 5, extent: 5, revision: run.revision))
        ..send(OpenRawBlock(run.leaf(2), atEnd: true, revision: run.revision));
      expect(run.shown.raw?.text, '<p>');
      run.pause();
      expect(run.sent, '<nav>\n\na\n\n<p>');
    });

    test('stays open through a change elsewhere that keeps its text', () {
      final run = EditorRun('a\n\n<div>\n\nb');
      run.owner.send(
        OpenRawBlock(run.leaf(1), atEnd: true, revision: run.revision),
      );
      run.owner.send(
        const FromFile(Replaced('a!\n\n<div>\n\nb', version: v2, ackRev: 0)),
      );
      expect(run.shown.raw?.text, '<div>');
      run.owner.send(
        const FromFile(Replaced('a!\n\n<p>\n\nb', version: v2, ackRev: 0)),
      );
      expect(run.shown.raw, isNull);
    });
  });

  test('securing sends the text first', () {
    final run = EditorRun('ab')..type('x');
    run.owner.send(const SecureEditor(SecureReason.hide));
    expect(
      run.outputs.whereType<ToFile>().map((out) => out.input.runtimeType),
      [Edited, Secure],
    );
    expect(run.sent, 'xab');
  });

  test('with a file owner, a change elsewhere after a save shows', () {
    final editor = EditorRun('a');
    final file = openedFileOwner(const Seen('a', v1));
    editor.owner.outputs.listen((output) {
      if (output case ToFile(:final input)) file.send(input);
    });
    file.outputs.listen((FileOutput output) {
      if (output case final ToEditor message) {
        editor.owner.send(FromFile(message));
      }
    });
    editor
      ..caret(0, 1)
      ..type('b')
      ..pause();
    file.send(Observed(const Found(Seen('ab', v2)), startedAt: Moment.now()));
    file.send(
      Observed(const Found(Seen('abc', Version(3))), startedAt: Moment.now()),
    );
    expect(editor.rows, ['abc']);
    expect(file.state.text, 'abc');
    editor
      ..type('d')
      ..pause();
    expect(editor.edits.last.lineage, const Version(3));
  });
}
