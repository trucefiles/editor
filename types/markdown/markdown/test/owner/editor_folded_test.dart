import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart';

import 'editor_run.dart';

/// A text, then a list with only checked items, its Done section folded:
/// once the text goes, no row shows.
const _text = 'x\n\n- [x] b';

EditorRun _folded(String text) {
  final run = EditorRun(text, checkedItems: CheckedItems.doneSection);
  final list = run.shown.view.doc.root.children.whereType<ListNode>().single.id;
  return run..send(SetCollapsed(list, collapsed: true));
}

/// Whether the selection is on a row that shows.
bool _onShownRow(EditorRun run) => switch (run.shown.selection) {
  null => true,
  TextSelection(:final base, :final extent) =>
    run.shown.view.row(base.leaf) != null &&
        run.shown.view.row(extent.leaf) != null,
  BlockSelection(:final block) ||
  BlockCaret(:final block) => run.shown.view.row(block) != null,
};

void main() {
  group('with no row shown, the caret is gone', () {
    test('the text deleted in Markdown edit', () {
      final run = _folded(_text)
        ..caret(0, 1)
        ..send(const SetMode(EditMode.markdown))
        ..editText('- [x] b')
        ..send(const SetMode(EditMode.visual));
      expect(run.rows, isEmpty);
      expect(run.shown.selection, isNull);
    });

    test('a Markdown edit step that added the text, undone', () {
      final run = _folded('- [x] b')
        ..send(const SetMode(EditMode.markdown))
        ..editText(_text)
        ..send(const SetMode(EditMode.visual))
        ..caret(0, 1)
        ..request(const Undo());
      expect(run.rows, isEmpty);
      expect(run.shown.selection, isNull);
    });

    test('the text deleted on another device', () {
      final run = _folded(_text)
        ..caret(0, 1)
        ..request(const FromFile(Replaced('- [x] b', version: v2, ackRev: 0)));
      expect(run.rows, isEmpty);
      expect(run.shown.selection, isNull);
    });
  });

  group('the caret never lands in a folded Done section', () {
    test('after a Separator at the end', () {
      final run = _folded(_text)..caret(0, 1);
      run.runCommand(AddDivider(run.leaf(0)));
      expect(run.rows, ['x', '[DividerNode]']);
      expect(_onShownRow(run), isTrue);
    });

    test('an Undo into a folded Done section opens it', () {
      final run = _folded('x\n\n- [x] b');
      final list = run.shown.view.doc.root.children.last.id;
      run
        ..send(SetCollapsed(list, collapsed: false))
        ..caret(1, 1)
        ..type('!')
        ..send(SetCollapsed(list, collapsed: true))
        ..caret(0, 0)
        ..request(const Undo());
      expect(run.rows, ['x', 'b']);
      expect(run.shown.view.done!.collapsed, isEmpty);
      expect(_onShownRow(run), isTrue);
    });

    test('an Undo in Markdown edit into a folded Done section opens it '
        'back in Visual edit', () {
      final run = _folded('x\n\n- [x] b');
      final list = run.shown.view.doc.root.children.last.id;
      run
        ..send(SetCollapsed(list, collapsed: false))
        ..caret(1, 1)
        ..type('!')
        ..send(SetCollapsed(list, collapsed: true))
        ..send(const SetMode(EditMode.markdown))
        ..request(const Undo())
        ..send(const SetMode(EditMode.visual));
      expect(run.rows, ['x', 'b']);
      expect(_onShownRow(run), isTrue);
    });

    test('after a divider deleted by Backspace', () {
      final run = _folded('---\n\n- [x] b')..select(0);
      run.press(EditKey.backspace);
      expect(_onShownRow(run), isTrue);
    });
  });
}
