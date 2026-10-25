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
      expect(run.state.lineage, _v2);
      // Its line changed: the caret goes to the kept line before it.
      expect(run.state.selection, TextSelection.caret(Place(run.slot(0), 1)));
      expect(run.edits, isEmpty);
    });

    test('a change elsewhere after an edit not seen there is ignored', () {
      final run = _Run('ab')..type('x');
      run.owner.send(const FromFile(Replaced('z', version: _v2, ackRev: 0)));
      expect(run.text, 'xab');
      expect(run.state.lineage, _v1);
    });

    test('a pick always shows, and later edits descend from it', () {
      final run = _Run('ab')..type('x');
      run.owner.send(const FromFile(Picked('z', version: _v2)));
      expect(run.text, 'z');
      run.type('y');
      expect(run.edits.last.lineage, _v2);
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

    test('toggled back wait for nothing', () {
      final run = _Run('- [ ] a\n- [ ] b')
        ..toggle(0)
        ..toggle(0);
      expect(run.state.holds.isEmpty, isTrue);
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
      run.owner.send(const SetCheckedItems(CheckedItems.inPlace));
      expect(run.state.holds.isEmpty, isTrue);
      expect(run.text, '- [x] a\n- [ ] b');
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
      run.owner.send(UndoRemoval(removed.id));
      expect(run.text, '- a\n- b');
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
    expect(editor.state.lineage, const Version(3));
    expect(file.state.text, 'abc');
  });
}
