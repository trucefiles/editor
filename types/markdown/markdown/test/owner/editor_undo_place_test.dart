import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart';

import 'editor_run.dart';

extension on EditorRun {
  void undo() => request(const Undo());
  void redo() => request(const Redo());

  /// The text of the row Visual edit was last told to show.
  String get rowShown {
    final leaf = outputs.whereType<ShowRow>().last.leaf;
    return textOf(shown.view.row(leaf)!.leaf).text;
  }

  int? get markdownCaret => (state.content as MarkdownContent).caret;
}

const _list = '- [ ] a\n- [ ] b\n- [ ] c\n- [ ] d';

EditorRun _listRun() => EditorRun(_list, checkedItems: CheckedItems.inPlace);

void main() {
  group('Visual edit undo and redo show the row the step acted at', () {
    test('typing', () {
      final run = EditorRun('one\n\ntwo\n\nthree')
        ..caret(2, 5)
        ..type('s')
        ..caret(0, 0)
        ..undo();
      expect(run.rowShown, 'three');
      run.redo();
      expect(run.rowShown, 'threes');
    });

    test('a box tap, with no caret', () {
      final run = _listRun()
        ..toggle(2)
        ..undo();
      expect(run.rowShown, 'c');
      run.redo();
      expect(run.rowShown, 'c');
    });

    test('a move, at both of its places', () {
      final run = _listRun();
      run
        ..runCommand(MoveItem(run.item(0), run.item(3), below: true))
        ..undo();
      expect(run.rows.first, 'a');
      expect(run.rowShown, 'a');
      run.redo();
      expect(run.rows.last, 'a');
      expect(run.rowShown, 'a');
    });

    test('a deleted item: back, then the next row that stays', () {
      final run = _listRun();
      run
        ..runCommand(DeleteItem(run.item(1)))
        ..undo();
      expect(run.rowShown, 'b');
      run.redo();
      expect(run.rowShown, 'c');
    });

    test('items cleared: the first back, then the next row that stays', () {
      final run = EditorRun(
        '- [ ] a\n- [x] b\n- [x] c\n- [ ] d',
        checkedItems: CheckedItems.inPlace,
      )..runCommand(const ClearChecked());
      expect(run.rows, ['a', 'd']);
      run.undo();
      expect(run.rowShown, 'b');
      run.redo();
      expect(run.rowShown, 'd');
    });

    test('the last item deleted: the row before it', () {
      final run = _listRun();
      run
        ..runCommand(DeleteItem(run.item(3)))
        ..undo()
        ..redo();
      expect(run.rowShown, 'c');
    });

    test('an item added', () {
      final run = _listRun();
      run
        ..runCommand(AddItem(run.shown.view.doc.root.children.single.id))
        ..undo();
      expect(run.rowShown, 'd');
      run.redo();
      expect(run.rows.last, '');
      expect(run.rowShown, '');
    });

    test('a step made in Markdown edit, at the line it changed', () {
      final run = EditorRun('one\n\ntwo\n\nthree')
        ..send(const SetMode(EditMode.markdown));
      run
        ..send(EditText('one\n\ntwo!\n\nthree', revision: run.revision))
        ..send(const SetMode(EditMode.visual))
        ..undo();
      expect(run.rows, ['one', 'two', 'three']);
      expect(run.rowShown, 'two');
      run.redo();
      expect(run.rowShown, 'two!');
    });
  });

  group('Markdown edit undo and redo put the caret', () {
    test('at the change, for a step made there', () {
      final run = EditorRun('one two', mode: EditMode.markdown);
      run
        ..send(EditText('one, two', revision: run.revision))
        ..undo();
      expect(run.markdownCaret, 3);
      run.redo();
      expect(run.markdownCaret, 4);
    });

    test('at the start of the row, for a step made in Visual edit', () {
      final run = _listRun()
        ..toggle(2)
        ..send(const SetMode(EditMode.markdown))
        ..undo();
      expect(run.markdownCaret, _list.indexOf('- [ ] c'));
      run.redo();
      expect(run.markdownCaret, _list.indexOf('- [ ] c'));
    });
  });
}
