import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/doc/load.dart';
import 'package:truce_markdown/src/edit/commands/command.dart';
import 'package:truce_markdown/src/edit/selection.dart';
import 'package:truce_markdown/src/view/changed_row.dart';
import 'package:truce_markdown/src/view/rows.dart';
import 'package:truce_markdown/src/visible/formatting.dart';

void main() {
  final before = ViewRows(
    loadMarkdown('# Shop\n\n- [ ] milk\n- [ ] eggs\n- [ ] oats\n\nend').doc,
  );
  final rows = before.rows;
  final items = nodesIn(before.doc.root).whereType<ItemNode>().toList();

  /// [before] with [command] run on it.
  ViewRows edited(Command command) =>
      ViewRows(run(before, command).doc, done: before.done);

  test('nothing changed: no row', () {
    expect(firstChangedRow(before, before), isNull);
  });

  test('the row whose text changed, not the rows before it', () {
    final typed = edited(
      InsertText(Place(rows[3].leaf.id, 4), 's', Formatting.plain),
    );
    expect(firstChangedRow(before, typed), rows[3].leaf.id);
  });

  test('the row of an item whose box or level changed', () {
    expect(
      firstChangedRow(before, edited(Toggle(items[1].id))),
      rows[2].leaf.id,
    );
    final indented = edited(
      Indent(TextSelection.caret(Place(rows[3].leaf.id, 0))),
    );
    expect(firstChangedRow(before, indented), rows[3].leaf.id);
  });

  test('the row now where rows went', () {
    final deleted = edited(DeleteItem(items[1].id));
    expect(firstChangedRow(before, deleted), rows[3].leaf.id);
    expect(firstChangedRow(deleted, before), rows[2].leaf.id);
  });
}
