import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/tree/blocks.dart';

import '../spec/spec_examples.dart';
import '../support/note_corpus.dart';

void main() {
  final texts = [
    ...noteCorpus,
    for (final spec in ['commonmark-0.31.2.txt', 'gfm-0.29-extensions.txt'])
      for (final example in specExamples(spec))
        example.markdown.replaceFirst(RegExp(r'\n$'), ''),
  ];

  group('every reading', () {
    test('keeps the text', () {
      for (final text in texts) {
        expect(NoteTree.read(text).text, text);
      }
    });

    test('gives each text leaf inline text whose source is its content', () {
      for (final text in texts) {
        for (final leaf in NoteTree.read(text).leaves.whereType<TextLeaf>()) {
          expect(leaf.text.source, leaf.content, reason: text);
        }
      }
    });

    test('puts each line in at most one leaf, leaves in file order', () {
      for (final text in texts) {
        final tree = NoteTree.read(text);
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
        final tree = NoteTree.read(text);
        for (final line in tree.lines) {
          if (tree.leafOf(line.id) != null) continue;
          expect(line.text, matches(_layout), reason: text);
        }
      }
    });

    test('gives every block its own id', () {
      for (final text in texts) {
        final ids = idsIn(NoteTree.read(text).root).toList();
        expect(ids.toSet().length, ids.length, reason: text);
      }
    });
  });

  group('reads', () {
    test('front matter only when closed', () {
      expect(
        NoteTree.read('---\na: b\n---\ntext').root.children.first,
        isA<FrontMatterBlock>(),
      );
      expect(
        NoteTree.read('---\na: b\ntext').root.children.first,
        isA<RuleBlock>(),
      );
    });

    test('a box at the line end as a box', () {
      final item = (NoteTree.read('- [ ]').root.children.single as ListBlock)
          .items
          .single;
      expect(item.checked, isFalse);
      expect(item.isEmpty, isTrue);
    });

    test('a text line over a lone `-` as a heading, as the standard says', () {
      expect(
        NoteTree.read('Shopping\n-').root.children.single,
        isA<HeadingBlock>(),
      );
    });

    test('quotes with the `>` lines after their last block', () {
      final tree = NoteTree.read('> a\n>\n\nb');
      final quote = tree.root.children.first as QuoteBlock;
      expect(tree.indexOf(quote.lastLine), 1);
    });

    test('numbering', () {
      ListBlock list(String text) =>
          NoteTree.read(text).root.children.single as ListBlock;
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
