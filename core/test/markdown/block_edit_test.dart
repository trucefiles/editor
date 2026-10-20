import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

import 'markdown_lines_support.dart';

/// The mapping from editor blocks back to file lines: each block edit
/// changes only its own line.
void main() {
  Set<LineId> all(MarkdownLines doc) => {for (final l in doc.lines) l.id};

  /// Each line shown right below the one above it, as in Markdown edit.
  Map<LineId, LineId> inFileOrder(MarkdownLines doc) => {
    for (var i = 1; i < doc.lines.length; i++)
      doc.lines[i - 1].id: doc.lines[i].id,
  };

  MarkdownLines apply(MarkdownLines doc, List<BlockEdit> edits) =>
      doc.applyEdits(edits, shownBelow: inFileOrder(doc)).$1;

  group('a changed block', () {
    test('unchanged keeps the exact bytes', () {
      final doc = MarkdownLines.parse('*   [X] milk  \n# Head  ');

      final same = apply(doc, [
        BlockChanged(
          idOf(doc, 'milk  '),
          const ItemBlock(
            kind: ListKind.checkbox,
            checked: true,
            depth: 0,
            text: 'milk  ',
          ),
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
          const ItemBlock(
            kind: ListKind.checkbox,
            checked: true,
            depth: 1,
            text: 'oat milk',
          ),
        ),
      ]);

      expect(changed.text, '\t*   [X] oat milk\nnext');
    });

    test('a toggle changes only the mark', () {
      final doc = MarkdownLines.parse('+ [ ] a');

      final toggled = apply(doc, [
        BlockChanged(
          idOf(doc, 'a'),
          const ItemBlock(
            kind: ListKind.checkbox,
            checked: true,
            depth: 0,
            text: 'a',
          ),
        ),
      ]);

      expect(toggled.text, '+ [x] a');
    });

    test('a new depth uses the file indent', () {
      final doc = MarkdownLines.parse('- [ ] a\n\t- [ ] b\n- [ ] c');

      final indented = apply(doc, [
        BlockChanged(
          idOf(doc, 'c'),
          const ItemBlock(
            kind: ListKind.checkbox,
            checked: false,
            depth: 1,
            text: 'c',
          ),
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
          const ItemBlock(
            kind: ListKind.checkbox,
            checked: false,
            depth: 0,
            text: 'a',
          ),
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
          ItemBlock(
            kind: ListKind.checkbox,
            checked: false,
            depth: 0,
            text: 'b',
          ),
          TextBlock('more'),
        ], after: idOf(doc, 'a')),
      ], shownBelow: inFileOrder(doc));

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
      final shownBelow = {idOf(doc, 'a'): idOf(doc, 'c')};

      final (added, _) = doc.applyEdits([
        BlocksAdded(const [
          ItemBlock(
            kind: ListKind.checkbox,
            checked: false,
            depth: 0,
            text: 'b',
          ),
        ], after: idOf(doc, 'a')),
      ], shownBelow: shownBelow);

      expect(added.text, '- [ ] a\n  - [x] done\n- [ ] b\n- [ ] c');
    });

    test('skip the subitems of the line above shown in its Done section', () {
      final doc = MarkdownLines.parse('- [ ] a\n  - [x] a1\n- [ ] b');
      final entries = const Arrangement(doneSection: true).of(doc);

      final (added, _) = doc.applyEdits([
        BlocksAdded(const [
          ItemBlock(kind: ListKind.checkbox, depth: 0, text: 'new'),
        ], after: idOf(doc, 'a')),
      ], shownBelow: linesShownBelow(entries));

      expect(added.text, '- [ ] a\n  - [x] a1\n- [ ] new\n- [ ] b');
    });

    test('a checked new item gets a checked box', () {
      final doc = MarkdownLines.parse('');

      final added = apply(doc, [
        BlocksAdded(const [
          ItemBlock(
            kind: ListKind.checkbox,
            checked: true,
            depth: 0,
            text: 'x',
          ),
        ], after: doc.lines.single.id),
      ]);

      expect(added.text, '\n- [x] x');
    });

    test('get ids never used before', () {
      final doc = MarkdownLines.parse('a\nb');

      final (removed, _) = doc.applyEdits([
        BlockRemoved(idOf(doc, 'b')),
      ], shownBelow: inFileOrder(doc));
      final (_, ids) = removed.applyEdits([
        BlocksAdded(const [TextBlock('c')], after: idOf(doc, 'a')),
      ], shownBelow: inFileOrder(removed));

      expect(all(doc), isNot(contains(ids.single)));
    });
  });

  group('list kinds', () {
    test('a kind whose text starts further in takes the lines in it', () {
      final doc = MarkdownLines.parse(
        '- a\n  - b\n    ```\n    code\n    ```\nlazy',
      );

      final changed = apply(doc, [
        BlockChanged(
          idOf(doc, 'a'),
          const ItemBlock(kind: ListKind.numbered, depth: 0, text: 'a'),
        ),
      ]);

      expect(changed.text, '1. a\n   - b\n     ```\n     code\n     ```\nlazy');
      expect(changed.depthOf(changed.lineOf(idOf(doc, 'b'))!), 1);
    });

    test('a kind whose text starts as far in leaves the lines in it', () {
      final doc = MarkdownLines.parse('- a\n  - b');

      final changed = apply(doc, [
        BlockChanged(
          idOf(doc, 'a'),
          const ItemBlock(kind: ListKind.checkbox, depth: 0, text: 'a'),
        ),
      ]);

      expect(changed.text, '- [ ] a\n  - b');
    });

    test('a bullet or numbered item keeps its marker style', () {
      final doc = MarkdownLines.parse('+   a\n7)  b');

      final changed = apply(doc, [
        BlockChanged(
          idOf(doc, 'a'),
          const ItemBlock(kind: ListKind.bullet, depth: 0, text: 'x'),
        ),
        BlockChanged(
          idOf(doc, 'b'),
          const ItemBlock(kind: ListKind.numbered, depth: 0, text: 'y'),
        ),
      ]);

      expect(changed.text, '+   x\n7)  y');
    });

    test('another kind changes the marker, keeping indent and bullet', () {
      final doc = MarkdownLines.parse('  * a');

      final changed = apply(doc, [
        BlockChanged(
          idOf(doc, 'a'),
          const ItemBlock(
            kind: ListKind.checkbox,
            checked: true,
            depth: 1,
            text: 'a',
          ),
        ),
      ]);

      expect(changed.text, '  * [x] a');
    });

    test('a new item after a numbered one takes the next number', () {
      final doc = MarkdownLines.parse('1. a');

      final (added, _) = doc.applyEdits([
        BlocksAdded(const [
          ItemBlock(kind: ListKind.numbered, depth: 0, text: 'b'),
        ], after: idOf(doc, 'a')),
      ], shownBelow: inFileOrder(doc));

      expect(added.text, '1. a\n2. b');
    });
  });
}
