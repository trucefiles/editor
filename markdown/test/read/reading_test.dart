import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/tree/blocks.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';

import '../spec/spec_examples.dart';
import '../support/document_corpus.dart';
import '../support/tree_dump.dart';

void main() {
  final texts = [
    ...documentCorpus,
    for (final spec in ['commonmark-0.31.2.txt', 'gfm-0.29-extensions.txt'])
      for (final example in specExamples(spec))
        example.markdown.replaceFirst(RegExp(r'\n$'), ''),
  ];

  group('every reading', () {
    test('keeps the text', () {
      for (final text in texts) {
        expect(DocumentTree.read(text).text, text);
      }
    });

    test('reads `\\r\\n` and `\\r` line endings as `\\n`, each line keeping its own', () {
      for (final text in texts) {
        final lf = dumpTree(DocumentTree.read(text));
        for (final ending in ['\r\n', '\r']) {
          final other = text.replaceAll('\n', ending);
          final tree = DocumentTree.read(other);
          expect(dumpTree(tree), lf, reason: text);
          expect(tree.text, other);
        }
      }
      final mixed = DocumentTree.read('# A\r\n\r\n- [ ] b\r---\nc');
      expect(
        [for (final line in mixed.lines) line.ending],
        ['\r\n', '\r\n', '\r', '\n', ''],
      );
      expect(mixed.root.children.map((block) => block.runtimeType), [
        HeadingBlock,
        ListBlock,
        RuleBlock,
        ParagraphBlock,
      ]);
      expect(mixed.lineEnding, '\r\n');
    });

    test('keeps a byte order mark apart from the first line', () {
      final tree = DocumentTree.read('\uFEFF---\na: b\n---\ntext');
      expect(tree.byteOrderMark, isTrue);
      expect(tree.root.children.first, isA<FrontMatterBlock>());
      expect(tree.text, '\uFEFF---\na: b\n---\ntext');
    });

    test('gives each text leaf inline text whose source is its content', () {
      for (final text in texts) {
        for (final leaf in DocumentTree.read(
          text,
        ).leaves.whereType<TextLeaf>()) {
          expect(leaf.text.source, leaf.content, reason: text);
        }
      }
    });

    test('puts each line in at most one leaf, leaves in file order', () {
      for (final text in texts) {
        final tree = DocumentTree.read(text);
        final indexes = [
          for (final leaf in tree.leaves)
            for (final line in leaf.lines) tree.indexOf(line.id),
        ];
        expect(indexes, indexes.sorted((a, b) => a - b), reason: text);
        expect(indexes.toSet().length, indexes.length, reason: text);
      }
    });

    test('leaves out of leaves only layout: blank, `>` and marker lines', () {
      for (final text in texts) {
        final tree = DocumentTree.read(text);
        for (final line in tree.lines) {
          if (tree.leafOf(line.id) != null) continue;
          expect(line.text, matches(_layout), reason: text);
        }
      }
    });

    test('gives every block its own id', () {
      for (final text in texts) {
        final ids = idsIn(DocumentTree.read(text).root).toList();
        expect(ids.toSet().length, ids.length, reason: text);
      }
    });
  });

  group('reads', () {
    test('front matter only when closed', () {
      expect(
        DocumentTree.read('---\na: b\n---\ntext').root.children.first,
        isA<FrontMatterBlock>(),
      );
      expect(
        DocumentTree.read('---\na: b\ntext').root.children.first,
        isA<RuleBlock>(),
      );
    });

    test('the text after front matter', () {
      expect(
        DocumentTree.read('---\na: b\n---\n# A\ntext').textAfterFrontMatter,
        '# A\ntext',
      );
      expect(DocumentTree.read('# A\ntext').textAfterFrontMatter, '# A\ntext');
    });

    test('character references only by their whole name', () {
      final leaf =
          DocumentTree.read('&ampx; &copycat; &amp; &semi; &copy;')
                  .leaves
                  .single
              as TextLeaf;
      expect(visibleTextOf(leaf.text).text, '&ampx; &copycat; & ; ©');
    });

    test('a box at the line end as a box', () {
      final item =
          (DocumentTree.read('- [ ]').root.children.single as ListBlock)
              .items
              .single;
      expect(item.checked, isFalse);
      expect(item.isEmpty, isTrue);
    });

    test('a text line over a lone `-` as a heading, as the standard says', () {
      expect(
        DocumentTree.read('Shopping\n-').root.children.single,
        isA<HeadingBlock>(),
      );
    });

    test('quotes with the `>` lines after their last block', () {
      final tree = DocumentTree.read('> a\n>\n\nb');
      final quote = tree.root.children.first as QuoteBlock;
      expect(tree.indexOf(quote.lastLine), 1);
    });

    test('indented code without the blank `>` lines after it', () {
      final tree = DocumentTree.read('>     code\n>\n> text');
      final code = tree.leaves.first as CodeBlock;
      expect([for (final line in code.lines) line.text], ['>     code']);
    });

    test('numbering', () {
      ListBlock list(String text) =>
          DocumentTree.read(text).root.children.single as ListBlock;
      expect(list('1. a\n1. b').numbering, Numbering.same);
      expect(list('1. a\n2. b').numbering, Numbering.sequential);
      expect(list('3. a').numbering, Numbering.sequential);
    });
  });
}

/// A line that holds only containers' marks: `>`, list markers and boxes.
final _layout = RegExp(
  r'^(?:[ \t>]|[-+*](?=[ \t]|$)|\d{1,9}[.)](?=[ \t]|$)|\[[ xX]\])*$',
);
