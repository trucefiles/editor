import 'package:test/test.dart';
import 'package:truce_core/src/note/lines/line.dart';
import 'package:truce_core/src/note/edit/redraft.dart';
import 'package:truce_core/src/note/note_tree.dart';
import 'package:truce_core/src/note/tree/blocks.dart';
import 'package:truce_core/src/note/visible/formatting.dart';
import 'package:truce_core/src/note/visible/visible_text.dart';
import 'package:truce_core/src/note/write/draft.dart';
import 'package:truce_core/src/note/write/note_writer.dart';

void main() {
  group('text', () {
    test('typing changes only the line typed on', () {
      final tree = NoteTree.read('Fish &amp; chips\\\ncost 5\\*3 now');
      final paragraph = tree.root.children.single as ParagraphBlock;
      final after = written(
        tree,
        RootDraft(tree.root, [
          TextDraft(
            paragraph.id,
            visibleTextOf(paragraph.text) + _plain('!'),
            from: [paragraph],
          ),
        ]),
      );
      expect(after.text, 'Fish &amp; chips\\\ncost 5\\*3 now!');
      expect(_ids(after), _ids(tree));
    });

    test('a split writes a new paragraph after a blank line', () {
      final tree = NoteTree.read('ab');
      final paragraph = tree.root.children.single as ParagraphBlock;
      final fresh = tree.freshBlockIds.first;
      final after = written(
        tree,
        RootDraft(tree.root, [
          TextDraft(paragraph.id, _plain('a'), from: [paragraph]),
          TextDraft(fresh, _plain('b')),
        ]),
      );
      expect(after.text, 'a\n\nb');
      expect(
        [for (final block in after.root.children) block.id],
        [paragraph.id, fresh],
      );
      expect(after.lines.first.id, tree.lines.first.id);
    });

    test('a join writes one paragraph from both', () {
      final tree = NoteTree.read('a\n\n*b*');
      final [first, second] = tree.leaves.cast<ParagraphBlock>();
      final after = written(
        tree,
        RootDraft(tree.root, [
          TextDraft(
            first.id,
            visibleTextOf(first.text) + visibleTextOf(second.text),
            from: [first, second],
          ),
        ]),
      );
      expect(after.text, 'a*b*');
    });

    test('a heading level changes only its marks', () {
      final tree = NoteTree.read('## Title ##\n\ntext');
      final heading = tree.leaves.first as HeadingBlock;
      final after = written(
        tree,
        RootDraft(tree.root, [
          TextDraft(
            heading.id,
            visibleTextOf(heading.text),
            level: 1,
            from: [heading],
          ),
          KeptDraft(tree.root.children.last),
        ]),
      );
      expect(after.text, '# Title\n\ntext');
    });

    test('a block written as it was under a new id takes that id', () {
      for (final note in ['a\n\nb', 'b\n\na', '- b\n- a', '- a\n- b']) {
        final tree = NoteTree.read(note);
        final b = tree.leaves.firstWhere(
          (leaf) => visibleTextOf((leaf as TextLeaf).text).text == 'b',
        );
        final id = tree.freshBlockIds.first;
        final draft = redrafted(tree, {
          b.id: [
            TextDraft(id, _plain('b'), from: [b as TextLeaf]),
          ],
        });
        final after = written(tree, draft);
        expect(after.text, note);
        expect(after.blockOf(id), isA<ParagraphBlock>(), reason: note);
      }
    });

    test('text in an empty heading goes after a space', () {
      for (final (note, expected) in [('##', '## x'), ('## ', '## x')]) {
        final tree = NoteTree.read(note);
        final heading = tree.leaves.first as HeadingBlock;
        expect(
          written(
            tree,
            RootDraft(tree.root, [
              TextDraft(heading.id, _plain('x'), level: 2, from: [heading]),
            ]),
          ).text,
          expected,
        );
      }
    });

    test('a note without blocks gets its first at its first line', () {
      for (final (note, expected) in [('', 'x'), ('\n', 'x\n')]) {
        final tree = NoteTree.read(note);
        expect(
          written(
            tree,
            RootDraft(tree.root, [
              TextDraft(tree.freshBlockIds.first, _plain('x')),
            ]),
          ).text,
          expected,
        );
      }
    });

    test('old blank lines between blocks stay', () {
      final tree = NoteTree.read('a\n\n\nb');
      final paragraph = tree.leaves.first as ParagraphBlock;
      expect(
        written(
          tree,
          RootDraft(tree.root, [
            TextDraft(
              paragraph.id,
              visibleTextOf(paragraph.text) + _plain('x'),
              from: [paragraph],
            ),
            KeptDraft(tree.root.children.last),
          ]),
        ).text,
        'ax\n\n\nb',
      );
    });

    test('lazy lines stay lazy', () {
      final tree = NoteTree.read('> a\nb');
      final quote = tree.root.children.single as QuoteBlock;
      final paragraph = quote.children.single as ParagraphBlock;
      final text = visibleTextOf(paragraph.text);
      expect(
        written(
          tree,
          RootDraft(tree.root, [
            QuoteDraft.of(quote, [
              TextDraft(
                paragraph.id,
                text.replaced(1, 1, _plain('x')),
                from: [paragraph],
              ),
            ]),
          ]),
        ).text,
        '> ax\nb',
      );
    });
  });

  group('quotes', () {
    test('new lines in a quote take its marks', () {
      final tree = NoteTree.read('>a');
      final quote = tree.root.children.single as QuoteBlock;
      expect(
        written(
          tree,
          RootDraft(tree.root, [
            QuoteDraft.of(quote, [
              KeptDraft(quote.children.single),
              TextDraft(tree.freshBlockIds.first, _plain('c')),
            ]),
          ]),
        ).text,
        '>a\n>\n>c',
      );
    });

    test('a block taken out of a quote loses its marks', () {
      final tree = NoteTree.read('> a\n> b');
      final quote = tree.root.children.single as QuoteBlock;
      final after = written(
        tree,
        RootDraft(tree.root, [KeptDraft(quote.children.single)]),
      );
      expect(after.text, 'a\nb');
      expect(_ids(after), _ids(tree));
    });
  });

  group('lists', () {
    test('code in an item holds no spaces on an empty line', () {
      final tree = NoteTree.read('```\n \nx\n```');
      final code = tree.root.children.single;
      final after = written(
        tree,
        RootDraft(tree.root, [
          ListDraft(
            tree.freshBlockIds.first,
            [
              ItemDraft(tree.freshBlockIds.skip(1).first, [KeptDraft(code)]),
            ],
            kind: ListKind.bullet,
            loose: false,
          ),
        ]),
      );
      expect((after.leaves.single as CodeBlock).code, '\nx');
    });

    test('a new item takes the style of the item above', () {
      final tree = NoteTree.read('*   a\n*   b');
      final list = tree.root.children.single as ListBlock;
      final [first, second] = list.items;
      final [item, paragraph] = tree.freshBlockIds.take(2).toList();
      expect(
        written(
          tree,
          RootDraft(tree.root, [
            ListDraft.of(list, [
              KeptDraft(first),
              ItemDraft(item, [TextDraft(paragraph, _plain('x'))]),
              KeptDraft(second),
            ]),
          ]),
        ).text,
        '*   a\n*   x\n*   b',
      );
    });

    test('a sequential list counts again after a new first item', () {
      final tree = NoteTree.read('1. a\n2. b');
      final list = tree.root.children.single as ListBlock;
      final [item, paragraph] = tree.freshBlockIds.take(2).toList();
      final after = written(
        tree,
        RootDraft(tree.root, [
          ListDraft.of(list, [
            ItemDraft(item, [TextDraft(paragraph, _plain('x'))]),
            for (final old in list.items) KeptDraft(old),
          ]),
        ]),
      );
      expect(after.text, '1. x\n2. a\n3. b');
    });

    test('a same-number list keeps its number', () {
      final tree = NoteTree.read('1. a\n1. b');
      final list = tree.root.children.single as ListBlock;
      final [item, paragraph] = tree.freshBlockIds.take(2).toList();
      expect(
        written(
          tree,
          RootDraft(tree.root, [
            ListDraft.of(list, [
              ...list.items.map(KeptDraft.new),
              ItemDraft(item, [TextDraft(paragraph, _plain('x'))]),
            ]),
          ]),
        ).text,
        '1. a\n1. b\n1. x',
      );
    });

    test('checking a box changes only the box', () {
      final tree = NoteTree.read('- [ ] a\n  b');
      final list = tree.root.children.single as ListBlock;
      final item = list.items.single;
      final after = written(
        tree,
        RootDraft(tree.root, [
          ListDraft.of(list, [
            ItemDraft.of(item, [
              ...item.children.map(KeptDraft.new),
            ], checked: true),
          ]),
        ]),
      );
      expect(after.text, '- [x] a\n  b');
      expect(_ids(after), _ids(tree));
    });

    test('text in an empty item goes on its marker line', () {
      final tree = NoteTree.read('- a\n-');
      final list = tree.root.children.single as ListBlock;
      final [first, empty] = list.items;
      expect(
        written(
          tree,
          RootDraft(tree.root, [
            ListDraft.of(list, [
              KeptDraft(first),
              ItemDraft.of(empty, [
                TextDraft(tree.freshBlockIds.first, _plain('b')),
              ]),
            ]),
          ]),
        ).text,
        '- a\n- b',
      );
    });

    test('a new empty item keeps its box with a space', () {
      final tree = NoteTree.read('- [ ] a');
      final list = tree.root.children.single as ListBlock;
      final fresh = tree.freshBlockIds.first;
      expect(
        written(
          tree,
          RootDraft(tree.root, [
            ListDraft.of(list, [
              KeptDraft(list.items.single),
              ItemDraft(fresh, [], checked: false),
            ]),
          ]),
        ).text,
        '- [ ] a\n- [ ] ',
      );
    });

    test('indenting an item makes it a subitem of the one above', () {
      final tree = NoteTree.read('- a\n- b');
      final list = tree.root.children.single as ListBlock;
      final [first, second] = list.items;
      final sublist = tree.freshBlockIds.first;
      final after = written(
        tree,
        RootDraft(tree.root, [
          ListDraft.of(list, [
            ItemDraft.of(first, [
              ...first.children.map(KeptDraft.new),
              ListDraft(
                sublist,
                [KeptDraft(second)],
                kind: ListKind.bullet,
                loose: false,
              ),
            ]),
          ]),
        ]),
      );
      expect(after.text, '- a\n  - b');
      expect(_ids(after), _ids(tree));
    });

    test('a loose list puts blank lines around a new item', () {
      final tree = NoteTree.read('- a\n\n- b');
      final list = tree.root.children.single as ListBlock;
      final [item, paragraph] = tree.freshBlockIds.take(2).toList();
      expect(
        written(
          tree,
          RootDraft(tree.root, [
            ListDraft.of(list, [
              ...list.items.map(KeptDraft.new),
              ItemDraft(item, [TextDraft(paragraph, _plain('x'))]),
            ]),
          ]),
        ).text,
        '- a\n\n- b\n\n- x',
      );
    });

    test('a list after a paragraph is written right below it', () {
      final tree = NoteTree.read('Shopping');
      final [list, item, paragraph] = tree.freshBlockIds.take(3).toList();
      expect(
        written(
          tree,
          RootDraft(tree.root, [
            ...tree.root.children.map(KeptDraft.new),
            ListDraft(
              list,
              [
                ItemDraft(item, [TextDraft(paragraph, _plain('milk'))]),
              ],
              kind: ListKind.bullet,
              loose: false,
            ),
          ]),
        ).text,
        'Shopping\n- milk',
      );
    });

    test('a list that cannot interrupt a paragraph gets a blank line', () {
      final tree = NoteTree.read('Shopping');
      final [list, item, paragraph] = tree.freshBlockIds.take(3).toList();
      expect(
        written(
          tree,
          RootDraft(tree.root, [
            ...tree.root.children.map(KeptDraft.new),
            ListDraft(
              list,
              [
                ItemDraft(item, [TextDraft(paragraph, _plain('milk'))]),
              ],
              kind: ListKind.numbered,
              loose: false,
              start: 2,
            ),
          ]),
        ).text,
        'Shopping\n\n2. milk',
      );
    });
  });

  group('blocks that would join', () {
    test('a list next to one of its kind takes the other marker', () {
      final tree = NoteTree.read('- a\n\n***\n\n- b');
      final [first, rule, second] = tree.root.children;
      expect(
        written(
          tree,
          RootDraft(tree.root, [KeptDraft(first), KeptDraft(second)]),
        ).text,
        '- a\n\n* b',
      );
      expect(rule, isA<RuleBlock>());
    });

    test('indented code moved below a list is fenced', () {
      final tree = NoteTree.read('    code\n\n- a');
      final [code, list] = tree.root.children;
      expect(
        written(
          tree,
          RootDraft(tree.root, [KeptDraft(list), KeptDraft(code)]),
        ).text,
        '- a\n```\ncode\n```',
      );
    });

    test('code an indented block cannot hold is fenced', () {
      final tree = NoteTree.read('    code\n\na');
      final [code, paragraph] = tree.root.children;
      String rewritten(String text) => written(
        tree,
        RootDraft(tree.root, [
          CodeDraft(code as CodeBlock, text),
          KeptDraft(paragraph),
        ]),
      ).text;
      expect(rewritten(''), '```\n```\n\na');
      expect(rewritten('\nx'), '```\n\nx\n```\n\na');
    });

    test('an open fence moved above a block is closed', () {
      final tree = NoteTree.read('a\n\n```\ncode');
      final [paragraph, code] = tree.root.children;
      expect(
        written(
          tree,
          RootDraft(tree.root, [KeptDraft(code), KeptDraft(paragraph)]),
        ).text,
        '```\ncode\n```\na',
      );
    });

    test('a quote next to a quote gets a blank line', () {
      final tree = NoteTree.read('> a\n\nb\n\n> c');
      final [first, _, second] = tree.root.children;
      expect(
        written(
          tree,
          RootDraft(tree.root, [KeptDraft(first), KeptDraft(second)]),
        ).text,
        '> a\n\n> c',
      );
    });
  });
}

VisibleText _plain(String text) =>
    VisibleText([TextPiece(text, Formatting.plain)]);

List<LineId> _ids(NoteTree tree) => [for (final line in tree.lines) line.id];
