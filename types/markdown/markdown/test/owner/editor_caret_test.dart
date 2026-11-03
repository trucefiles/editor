import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart';
import 'package:truce_test_support/truce_test_support.dart';

import 'editor_run.dart';

/// When a caret shows: none on opening a file, none after a control, back
/// with the next tap into text.
void main() {
  test('an existing file opens without a caret, a new one with it', () {
    expect(EditorRun('- [ ] a').shown.selection, isNull);
    final created = MachineRun.of(
      editorMachine(MarkdownStart.read(''), version: null),
    );
    expect(
      (created.state.content as FormattedContent).selection,
      isA<TextSelection>(),
    );
  });

  test('a tap into text places the caret', () {
    final run = EditorRun('ab')..caret(0, 1);
    expect(run.shown.selection, TextSelection.caret(Place(run.leaf(0), 1)));
  });

  group('a control leaves no caret', () {
    const list = '- [ ] a\n- [ ] b\n- [ ] c';

    test('a drop, a swipe or the delete button', () {
      for (final command in <Command Function(EditorRun run)>[
        (run) => MoveItem(run.item(0), run.item(2), below: true),
        (run) => Indent(TextSelection.caret(Place(run.leaf(1), 0))),
        (run) => DeleteItem(run.item(1)),
      ]) {
        final run = EditorRun(list)..caret(2, 1);
        run.send(Run(command(run), revision: run.revision, byControl: true));
        expect(run.shown.selection, isNull, reason: '$command');
      }
    });

    test('a box tap', () {
      final run = EditorRun(list)
        ..caret(2, 1)
        ..toggle(0);
      expect(run.rows, ['b', 'c', 'a']);
      expect(run.shown.selection, isNull);
    });

    test('folding a Done section', () {
      final run = EditorRun(
        '- [ ] a\n- [x] b',
        checkedItems: CheckedItems.doneSection,
      )..caret(0, 1);
      final list = run.shown.view.doc.root.children.single.id;
      run.send(SetCollapsed(list, collapsed: true));
      expect(run.shown.selection, isNull);
    });

    test('a command not from a control keeps the caret', () {
      final run = EditorRun(list)..caret(1, 0);
      run.runCommand(Indent(TextSelection.caret(Place(run.leaf(1), 0))));
      expect(run.shown.selection, TextSelection.caret(Place(run.leaf(1), 0)));
    });

    test('undo brings back the caret the step started with', () {
      final run = EditorRun(list)..caret(2, 1);
      run.send(
        Run(DeleteItem(run.item(0)), revision: run.revision, byControl: true),
      );
      run.request(const Undo());
      expect(run.shown.selection, TextSelection.caret(Place(run.leaf(2), 1)));
    });
  });

  group('without a caret', () {
    test('keys do nothing', () {
      final run = EditorRun('ab')..press(EditKey.enter);
      expect(run.rows, ['ab']);
    });

    test('a change from elsewhere shows none either', () {
      final run = EditorRun('ab')
        ..request(const FromFile(Replaced('ab\n\ncd', version: v2, ackRev: 0)));
      expect(run.rows, ['ab', 'cd']);
      expect(run.shown.selection, isNull);
    });

    test('Markdown edit and back shows none either', () {
      final run = EditorRun('ab')
        ..send(const SetMode(EditMode.markdown))
        ..send(const SetMode(EditMode.visual));
      expect(run.shown.selection, isNull);
    });
  });
}
