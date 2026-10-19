import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import 'markdown_lines_support.dart';

/// The mapping from editor blocks back to file lines: each block edit
/// changes only its own line.
void main() {
  Set<LineId> all(MarkdownLines doc) => {for (final l in doc.lines) l.id};

  MarkdownLines apply(MarkdownLines doc, List<BlockEdit> edits) =>
      doc.applyEdits(edits, shown: all(doc)).$1;

  group('a changed block', () {
    test('unchanged keeps the exact bytes', () {
      final doc = MarkdownLines.parse('*   [X] milk  \n# Head  ');

      final same = apply(doc, [
        BlockChanged(
          idOf(doc, 'milk  '),
          const ItemBlock(checked: true, depth: 0, text: 'milk  '),
        ),
        BlockChanged(idOf(doc, '# Head  '), const TextBlock('# Head  ')),
      ]);

      expect(same.text, doc.text);
    });

    test('new text keeps the prefix style', () {
      final doc = MarkdownLines.parse('\t*   [X] milk\nnext');

      final changed = apply(doc, [
        BlockChanged(
          idOf(doc, 'milk'),
          const ItemBlock(checked: true, depth: 1, text: 'oat milk'),
        ),
      ]);

      expect(changed.text, '\t*   [X] oat milk\nnext');
    });

    test('a toggle changes only the mark', () {
      final doc = MarkdownLines.parse('+ [ ] a');

      final toggled = apply(doc, [
        BlockChanged(
          idOf(doc, 'a'),
          const ItemBlock(checked: true, depth: 0, text: 'a'),
        ),
      ]);

      expect(toggled.text, '+ [x] a');
    });

    test('a new depth uses the file indent', () {
      final doc = MarkdownLines.parse('- [ ] a\n\t- [ ] b\n- [ ] c');

      final indented = apply(doc, [
        BlockChanged(
          idOf(doc, 'c'),
          const ItemBlock(checked: false, depth: 1, text: 'c'),
        ),
      ]);

      expect(indented.text, '- [ ] a\n\t- [ ] b\n\t- [ ] c');
    });

    test('a text block replaces the whole line', () {
      final doc = MarkdownLines.parse('- [ ] a\nb');

      final changed = apply(doc, [
        BlockChanged(idOf(doc, 'a'), const TextBlock('a')),
      ]);

      expect(changed.text, 'a\nb');
      expect(changed.lines.first.id, doc.lines.first.id);
    });

    test('an item block makes a text line an item', () {
      final doc = MarkdownLines.parse('a');

      final changed = apply(doc, [
        BlockChanged(
          idOf(doc, 'a'),
          const ItemBlock(checked: false, depth: 0, text: 'a'),
        ),
      ]);

      expect(changed.text, '- [ ] a');
    });

    test('line breaks in a block become spaces', () {
      final doc = MarkdownLines.parse('a');

      final changed = apply(doc, [
        BlockChanged(idOf(doc, 'a'), const TextBlock('a\nb')),
      ]);

      expect(changed.text, 'a b');
    });
  });

  test('a removed block removes only its line', () {
    final doc = MarkdownLines.parse('- [ ] a\n  - [ ] sub\n- [ ] b');

    final removed = apply(doc, [BlockRemoved(idOf(doc, 'a'))]);

    expect(removed.text, '  - [ ] sub\n- [ ] b');
  });

  group('added blocks', () {
    test('go after the line shown above, styled like the item above', () {
      final doc = MarkdownLines.parse('# Head\n* [ ] a\ntext');

      final (added, ids) = doc.applyEdits([
        BlocksAdded(const [
          ItemBlock(checked: false, depth: 0, text: 'b'),
          TextBlock('more'),
        ], after: idOf(doc, 'a')),
      ], shown: all(doc));

      expect(added.text, '# Head\n* [ ] a\n* [ ] b\nmore\ntext');
      expect(ids, [added.lines[2].id, added.lines[3].id]);
    });

    test('go to the top without a line above', () {
      final doc = MarkdownLines.parse('a');

      final added = apply(doc, [
        const BlocksAdded([TextBlock('top')], after: null),
      ]);

      expect(added.text, 'top\na');
    });

    test('skip the hidden subitems of the line above', () {
      final doc = MarkdownLines.parse('- [ ] a\n  - [x] done\n- [ ] c');
      final shown = all(doc)..remove(idOf(doc, 'done'));

      final (added, _) = doc.applyEdits([
        BlocksAdded(const [
          ItemBlock(checked: false, depth: 0, text: 'b'),
        ], after: idOf(doc, 'a')),
      ], shown: shown);

      expect(added.text, '- [ ] a\n  - [x] done\n- [ ] b\n- [ ] c');
    });

    test('a checked new item gets a checked box', () {
      final doc = MarkdownLines.parse('');

      final added = apply(doc, [
        BlocksAdded(const [
          ItemBlock(checked: true, depth: 0, text: 'x'),
        ], after: doc.lines.single.id),
      ]);

      expect(added.text, '\n- [x] x');
    });

    test('get ids never used before', () {
      final doc = MarkdownLines.parse('a\nb');

      final (removed, _) = doc.applyEdits([
        BlockRemoved(idOf(doc, 'b')),
      ], shown: all(doc));
      final (_, ids) = removed.applyEdits([
        BlocksAdded(const [TextBlock('c')], after: idOf(doc, 'a')),
      ], shown: all(removed));

      expect(all(doc), isNot(contains(ids.single)));
    });
  });
}
