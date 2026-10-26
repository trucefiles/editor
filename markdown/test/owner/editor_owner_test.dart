import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart'
    show
        Edited,
        FileOutput,
        FileTiming,
        Found,
        Observed,
        Picked,
        Replaced,
        Secure,
        SecureReason,
        Seen,
        ToEditor,
        Version,
        Moment,
        openedFileOwner;
import 'package:truce_markdown/truce_markdown.dart';

const _v1 = Version(1);
const _v2 = Version(2);

/// An editor owner with what it led to so far.
final class _Run {
  _Run(
    String text, {
    CheckedItems checkedItems = CheckedItems.moveToEnd,
    EditMode mode = EditMode.visual,
  }) : owner = editorOwner(
         text,
         version: _v1,
         checkedItems: checkedItems,
         mode: mode,
       ) {
    owner.outputs.listen(outputs.add);
  }

  final EditorOwner owner;
  final outputs = <EditorOutput>[];

  EditorState get state => owner.state;
  String get text => state.document.tree.text;
  int get revision => state.revision;

  List<Edited> get edits => [
    for (final output in outputs)
      if (output case ToFile(input: final Edited edited)) edited,
  ];

  /// The text place of the [index]th row.
  Slot slot(int index) => switch (state.document.rows[index]) {
    TextRow(:final slot) => slot,
    _ => throw StateError('no text in row $index'),
  };

  void caret(int row, int offset) => owner.send(
    CaretMoved(
      TextSelection.caret(Place(slot(row), offset)),
      revision: revision,
    ),
  );

  void type(String text) => owner.send(Typed(text, revision: revision));

  void press(EditKey key) => owner.send(Pressed(key, revision: revision));

  void runCommand(Command command) =>
      owner.send(Run(command, revision: revision));

  BlockId item(int index) =>
      (state.document.tree.root.children.first as ListBlock).items[index].id;

  void toggle(int index) =>
      owner.send(ToggleItem(item(index), revision: revision));

  void fireSettle() => owner.send(
    SettleTimerFired(outputs.whereType<StartSettleTimer>().last.id),
  );
}

void main() {
  group('typing', () {
    test('sends each text change to the file owner', () {
      final run = _Run('ab')
        ..caret(0, 1)
        ..type('x');
      expect(run.text, 'axb');
      expect(run.edits.single.text, 'axb');
      expect(run.edits.single.rev, 1);
      expect(run.edits.single.lineage, _v1);
    });

    test('takes the typing style set at the caret, until the caret moves', () {
      final run = _Run('ab')
        ..caret(0, 1)
        ..press(EditKey.bold)
        ..type('x');
      expect(run.text, 'a**x**b');
      run
        ..caret(0, 0)
        ..type('y');
      expect(run.text, 'ya**x**b');
    });

    test('refuses an input on what no longer shows', () {
      final run = _Run('ab');
      expect(
        () => run.owner.send(Typed('x', revision: run.revision - 1)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Markdown edit changes lines', () {
      final run = _Run('a\nb', mode: EditMode.markdown);
      run.owner.send(
        EditLines(
          LineChange(1, 2, [(id: null, text: '- b')]),
          revision: run.revision,
        ),
      );
      expect(run.text, 'a\n- b');
      expect(run.edits.single.text, 'a\n- b');
    });
  });

  group('changes from the file owner', () {
    test('a change elsewhere shows, the caret kept by its lines', () {
      final run = _Run('ab\n\ncd')..caret(1, 1);
      run.owner.send(
        const FromFile(Replaced('ab\n\ncd!', version: _v2, ackRev: 0)),
      );
      expect(run.text, 'ab\n\ncd!');
      // Its line changed: the caret goes to the kept line before it.
      expect(run.state.selection, TextSelection.caret(Place(run.slot(0), 1)));
      expect(run.edits, isEmpty);
      run.type('x');
      expect(run.edits.single.lineage, _v2);
    });

    test('a change elsewhere after an edit not seen there is ignored', () {
      final run = _Run('ab')..type('x');
      run.owner.send(const FromFile(Replaced('z', version: _v2, ackRev: 0)));
      expect(run.text, 'xab');
      run.type('y');
      expect(run.edits.last.lineage, _v1);
    });

    test('a change elsewhere drops a view-only tail', () {
      // The typed space is not in the file yet: a change read anew from
      // the file has no place for it (accepted, plan §2.4).
      final run = _Run('ab')
        ..caret(0, 2)
        ..type(' ');
      expect(run.state.document.textOf(run.slot(0)).text, 'ab ');
      expect(run.edits, isEmpty);
      run.owner.send(const FromFile(Replaced('ab!', version: _v2, ackRev: 0)));
      expect(run.state.document.textOf(run.slot(0)).text, 'ab!');
    });

    test('a pick always shows, and later edits descend from it', () {
      final run = _Run('ab')..type('x');
      // The file owner never got the edit at rev 1: revs go on from 0.
      run.owner.send(const FromFile(Picked('z', version: _v2, rev: 0)));
      expect(run.text, 'z');
      run.type('y');
      expect(
        (run.edits.last.lineage, run.edits.last.rev, run.edits.last.picks),
        (_v2, 1, 1),
      );
    });
  });

  group('checked items', () {
    test('with "Move to end" move once the toggle settles', () {
      final run = _Run('- [ ] a\n- [ ] b')
        ..caret(1, 0)
        ..toggle(0);
      expect(run.text, '- [x] a\n- [ ] b');
      run.fireSettle();
      expect(run.text, '- [ ] b\n- [x] a');
    });

    test('move once the user types in another item', () {
      final run = _Run('- [ ] a\n- [ ] b')
        ..caret(1, 1)
        ..toggle(0)
        ..type('x');
      expect(run.text, '- [ ] bx\n- [x] a');
    });

    test('toggled back wait for nothing', () {
      final run = _Run('- [ ] a\n- [ ] b')
        ..toggle(0)
        ..toggle(0)
        ..fireSettle();
      expect(run.text, '- [ ] a\n- [ ] b');
    });

    test('wait while the caret is in a toggled item', () {
      final run = _Run('- [ ] a\n- [ ] b')
        ..caret(0, 1)
        ..toggle(0)
        ..fireSettle();
      expect(run.text, '- [x] a\n- [ ] b');
      run.caret(1, 0);
      expect(run.text, '- [ ] b\n- [x] a');
    });

    test('in a Done section show in place until the toggle settles', () {
      final run =
          _Run('- [ ] a\n- [ ] b', checkedItems: CheckedItems.doneSection)
            ..caret(1, 0)
            ..toggle(0);
      expect(run.state.document.rows.first.done, isFalse);
      run.fireSettle();
      expect(run.state.document.rows.last.done, isTrue);
      expect(run.text, '- [x] a\n- [ ] b');
    });

    test('choosing how they show moves none', () {
      final run = _Run('- [ ] a\n- [ ] b')..toggle(0);
      run.owner
        ..send(const SetCheckedItems(CheckedItems.inPlace))
        ..send(const SetCheckedItems(CheckedItems.moveToEnd));
      run.fireSettle();
      expect(run.text, '- [x] a\n- [ ] b');
    });

    test('"Move to end now" moves waiting ones too, once', () {
      final run = _Run('- [ ] a\n- [x] b\n- [ ] c')..toggle(0);
      run.runCommand(MoveToEnd(run.state.selection));
      expect(run.text, '- [ ] c\n- [x] b\n- [x] a');
      run.fireSettle();
      expect(run.text, '- [ ] c\n- [x] b\n- [x] a');
    });

    test('are toggled by a box tap only, never a Toggle command', () {
      final run = _Run('- [ ] a');
      expect(
        () => run.runCommand(Toggle(run.item(0), run.state.selection)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('settle before the document is secured', () {
      final run = _Run('- [ ] a\n- [ ] b')..toggle(0);
      run.owner.send(const SecureEditor(SecureReason.hide));
      expect(run.text, '- [ ] b\n- [x] a');
      expect(
        run.outputs.last,
        isA<ToFile>().having((out) => out.input, 'input', isA<Secure>()),
      );
    });
  });

  group('removals', () {
    test('can be undone while the text did not change since', () {
      final run = _Run('- a\n- b');
      run.runCommand(DeleteItem(run.item(0)));
      final removed = run.outputs.whereType<ItemsRemoved>().single;
      final next = run.state.document.tree.freshBlockIds.first;
      run.owner.send(UndoRemoval(removed.id));
      expect(run.text, '- a\n- b');
      expect(run.state.document.tree.freshBlockIds.first, next);
    });

    test('of one code block are offered, of an emptied one not', () {
      final run = _Run('a\n\n```\nx\n```\n\nb');
      run.runCommand(
        DeleteRange(
          TextSelection(Place(run.slot(0), 1), Place(run.slot(1), 1)),
        ),
      );
      expect(run.text, 'a\n\nb');
      expect(run.outputs.whereType<ItemsRemoved>(), hasLength(1));
      final emptied = _Run('a\n\n```\n```\n\nb');
      emptied.runCommand(JoinWithPrevious(emptied.slot(1)));
      expect(emptied.text, 'a\n\nb');
      expect(emptied.outputs.whereType<ItemsRemoved>(), isEmpty);
    });

    test('cannot be undone after another edit', () {
      final run = _Run('- a\n- b');
      run.runCommand(DeleteItem(run.item(0)));
      final removed = run.outputs.whereType<ItemsRemoved>().single;
      run
        ..caret(0, 0)
        ..type('x')
        ..owner.send(UndoRemoval(removed.id));
      expect(run.outputs.last, isA<UndoRefused>());
      expect(run.text, '- xb');
    });
  });

  test('a one-line raw region grows into new lines', () {
    final run = _Run('a\n\n<!-- c -->\n\nb')..caret(2, 0);
    run.press(EditKey.backspace);
    run.owner.send(
      EditRaw('<!-- c -->\n', base: 11, extent: 11, revision: run.revision),
    );
    run.owner.send(
      EditRaw('<!-- c -->\nx', base: 12, extent: 12, revision: run.revision),
    );
    expect(run.text, 'a\n\n<!-- c -->\nx\n\nb');
  });

  test('a raw region edits the lines of a block without text', () {
    final run = _Run('a\n\n<div>\nx\n</div>\n\nb')..caret(2, 0);
    run.press(EditKey.backspace);
    expect(run.state.raw, isNotNull);
    run.owner.send(
      EditRaw('<div>\ny\n</div>', base: 7, extent: 7, revision: run.revision),
    );
    expect(run.text, 'a\n\n<div>\ny\n</div>\n\nb');
    expect(run.edits.last.text, run.text);
    run.caret(0, 0);
    expect(run.state.raw, isNull);
  });

  test('with a file owner, a change elsewhere after a save shows', () {
    final editor = _Run('a');
    final file = openedFileOwner(
      const Seen('a', _v1),
      timing: const FileTiming(),
    );
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
      ..type('b');
    file.send(Observed(const Found(Seen('ab', _v2)), startedAt: Moment.now()));
    file.send(
      Observed(const Found(Seen('abc', Version(3))), startedAt: Moment.now()),
    );
    expect(editor.text, 'abc');
    expect(file.state.text, 'abc');
    editor.type('d');
    expect(editor.edits.last.lineage, const Version(3));
  });
}
