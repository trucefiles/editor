import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/doc/load.dart';
import 'package:truce_markdown/src/view/rows.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';

List<String> _shown(ViewRows view) => [
  for (final row in view.rows)
    switch (row) {
      TextRow(:final leaf) => '${row.done ? 'done ' : ''}${textOf(leaf).text}',
      BlockRow(:final leaf) => '[${leaf.runtimeType}]',
    },
];

ViewRows _view(String text, {DoneSections? done}) =>
    ViewRows(loadMarkdown(text).doc, done: done);

void main() {
  test('rows show each leaf in order, blocks without text whole', () {
    expect(_shown(_view('# T\n\n> - a\n>   ```\n>   x\n>   ```\n\n---')), [
      'T',
      'a',
      'x',
      '[DividerNode]',
      '',
    ]);
  });

  test('Done sections show checked top-level items after the open ones', () {
    const text = '- [x] a\n  - [ ] sub\n- [ ] b\n  - [x] c\n  - [ ] d';
    expect(_shown(_view(text)), ['a', 'sub', 'b', 'c', 'd']);
    final view = _view(text, done: DoneSections());
    expect(_shown(view), ['b', 'c', 'd', 'done a', 'done sub']);
    final list = view.doc.root.children.first;
    expect(_shown(_view(text, done: DoneSections(collapsed: {list.id}))), [
      'b',
      'c',
      'd',
    ]);
  });

  test('a change derives anew only the rows of the nodes it rebuilt', () {
    final doc = loadMarkdown(
      [for (var item = 0; item < 3; item++) '- item $item'].join('\n'),
    ).doc;
    final before = ViewRows(doc);
    final list = doc.root.children.first as ListNode;
    final first = list.items.first.children.single as ParagraphNode;
    final changed = ViewRows(
      doc.withNode(first.withText(VisibleText([TextPiece('x')]))),
    );
    expect(changed.rows[1], same(before.rows[1]));
    expect(changed.rows.first, isNot(same(before.rows.first)));
    expect(changed.rowOf(first.id), 0);
  });
}
