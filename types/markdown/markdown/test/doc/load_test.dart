import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/doc/load.dart';
import 'package:truce_markdown/src/doc/normalized.dart';
import 'package:truce_markdown/src/tree/blocks.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';

import '../spec/spec_examples.dart';
import '../support/document_corpus.dart';

/// [block]'s kinds as a nested list, texts as they show.
Object _outline(DocBlock block) => switch (block) {
  DocRoot(:final children) => [for (final child in children) _outline(child)],
  QuoteNode(:final children) => {
    'quote': [for (final child in children) _outline(child)],
  },
  ListNode(:final kind, :final start, :final items) => {
    '${kind.name} $start': [for (final item in items) _outline(item)],
  },
  ItemNode(:final checked, :final children) => {
    'item $checked': [for (final child in children) _outline(child)],
  },
  ParagraphNode(:final text) => 'p ${text.text}',
  HeadingNode(:final level, :final text) => 'h$level ${text.text}',
  CodeNode(:final code, :final info) => 'code $info $code',
  DividerNode() => 'divider',
  TableNode(:final raw) => 'table $raw',
  RawNode(:final kind, :final raw) => '${kind.name} $raw',
};

Object _loaded(String text) => _outline(loadMarkdown(text).doc.root);

void main() {
  group('a loaded document', () {
    test('holds every kind of block as it reads', () {
      expect(
        _loaded(
          '---\na: b\n---\n# T\n\n> q\n\n- [ ] a\n  1. b\n\n```js\nx\n```\n\n'
          '---\n\n| a |\n|---|\n\n<div>\n\n[x]: /u\n\nend',
        ),
        [
          'frontMatter ---\na: b\n---',
          'h1 T',
          {
            'quote': ['p q'],
          },
          {
            'bullet 1': [
              {
                'item false': [
                  'p a',
                  {
                    'numbered 1': [
                      {
                        'item null': ['p b'],
                      },
                    ],
                  },
                ],
              },
            ],
          },
          'code js x',
          'divider',
          'table | a |\n|---|',
          'html <div>',
          'definitions [x]: /u',
          'p end',
        ],
      );
    });

    test('shows a text place where Markdown has none to type in', () {
      expect(_loaded(''), ['p ']);
      expect(_loaded('- \n- - a\n>'), [
        {
          'bullet 1': [
            {
              'item null': ['p '],
            },
            {
              'item null': [
                'p ',
                {
                  'bullet 1': [
                    {
                      'item null': ['p a'],
                    },
                  ],
                },
              ],
            },
          ],
        },
        {
          'quote': ['p '],
        },
      ]);
      expect(_loaded('a\n\n---'), ['p a', 'divider', 'p ']);
      expect(_loaded('a\n\n```\nx\n```'), ['p a', 'code  x', 'p ']);
    });

    test('ends with no text place after HTML that takes in the rest', () {
      expect(_loaded('<!-- open\nstill'), ['html <!-- open\nstill']);
      expect(_loaded('<!-- c -->'), ['html <!-- c -->', 'p ']);
    });

    test('holds a raw block\'s text without its first line\'s indent', () {
      expect(_loaded('  <div>\n  x'), ['html <div>\n  x', 'p ']);
      expect(_loaded(' [a]: /u'), ['definitions [a]: /u', 'p ']);
    });

    test('counts a numbered list from its first number', () {
      final list = loadMarkdown('3. a\n4. b').doc.root.children.first;
      expect((list as ListNode).start, 3);
      expect(list.numberAt(1), 4);
      final same = loadMarkdown('2. a\n2. b').doc.root.children.first;
      expect((same as ListNode).numbering, Numbering.same);
      expect(same.numberAt(1), 2);
    });

    test('gives every node its own id, and knows each as read', () {
      for (final text in [
        ...documentCorpus,
        for (final example in specExamples('commonmark-0.31.2.txt'))
          example.markdown,
      ]) {
        final (:doc, :origin) = loadMarkdown(text);
        final nodes = nodesIn(doc.root).toList();
        expect(nodes.map((node) => node.id).toSet().length, nodes.length);
        expect(nodes.every(origin.isLoaded), isTrue);
        expect(
          nodes
              .map((node) => node.id)
              .every((id) => doc.nodeOf(id) != null && doc.freshIds.next > 0),
          isTrue,
        );
      }
    });
  });

  group('a document tree', () {
    test('replaces a node by rebuilding only its path', () {
      final doc = loadMarkdown('- a\n- b\n\nc').doc;
      final list = doc.root.children.first as ListNode;
      final b = list.items[1].children.single as ParagraphNode;
      final changed = doc.withNode(b.withText(VisibleText([TextPiece('B')])));
      final changedList = changed.root.children.first as ListNode;
      expect(changedList.id, list.id);
      expect(changedList.items.first, same(list.items.first));
      expect(changed.root.children.last, same(doc.root.children.last));
      expect((changedList.items[1].children.single as TextNode).text.text, 'B');
      expect(changed.pathOf(b.id).map((node) => node.id), [
        doc.root.id,
        list.id,
        list.items[1].id,
      ]);
    });

    test('normalized keeps a document that needs nothing', () {
      final doc = loadMarkdown('- a\n\n> b\n\nc').doc;
      expect(normalized(doc, doc.freshIds), same(doc));
    });

    test('normalized drops empty lists and quotes', () {
      final doc = loadMarkdown('- a\n\n> b\n\nc').doc;
      final list = doc.root.children.first as ListNode;
      final emptied = doc.withNode(list.withChildren(const []));
      final fresh = emptied.freshIds;
      expect(_outline(normalized(emptied, fresh).root), [
        {
          'quote': ['p b'],
        },
        'p c',
      ]);
    });

    test('holds a node while it is the same object at its id', () {
      final doc = loadMarkdown('- a\n- b\n\nc').doc;
      final list = doc.root.children.first as ListNode;
      final b = list.items[1].children.single as ParagraphNode;
      final changed = doc.withNode(b.withText(VisibleText([TextPiece('B')])));

      expect(changed.holds(list.items.first), isTrue);
      expect(changed.holds(list), isFalse);
      expect(changed.holds(b), isFalse);
      expect(changed.nodesNotIn(doc).map((node) => node.id), [
        doc.root.id,
        list.id,
        list.items[1].id,
        b.id,
      ]);
    });

    test('normalized after an edit looks only at the nodes it rebuilt', () {
      final doc = loadMarkdown('- a\n\n> b\n\nc').doc;
      final list = doc.root.children.first as ListNode;
      final quote = doc.root.children[1] as QuoteNode;
      // An untidy list the tree before holds is taken as tidy.
      final before = doc.withNode(list.withChildren(const []));
      final edited = before.withNode(quote.withChildren(const []));

      expect(
        _outline(normalized(edited, edited.freshIds, before: before).root),
        [
          {'bullet 1': <Object>[]},
          'p c',
        ],
      );
    });

    test('normalized after random edits is as normalized whole', () {
      final random = Random(3);
      for (final text in documentCorpus) {
        final before = loadMarkdown(text).doc;
        for (var round = 0; round < 20; round++) {
          final nodes = nodesIn(before.root).skip(1).toList();
          if (nodes.isEmpty) break;
          final node = nodes[random.nextInt(nodes.length)];
          final edited = before.replaced(node.id, switch (node) {
            DocContainer(:final children) when random.nextBool() => [
              node.withChildren(children.skip(1).toList()),
            ],
            _ => const [],
          });
          final whole = normalized(edited, edited.freshIds);
          final tidied = normalized(edited, edited.freshIds, before: before);

          expect(_outline(tidied.root), _outline(whole.root), reason: text);
          expect(
            nodesIn(tidied.root).map((node) => node.id),
            nodesIn(whole.root).map((node) => node.id),
          );
        }
      }
    });

    test('the leaves an edit removed are found among the nodes it took '
        'away or rebuilt', () {
      final random = Random(5);
      for (final text in documentCorpus) {
        final before = loadMarkdown(text).doc;
        final nodes = nodesIn(before.root).skip(1).toList();
        if (nodes.isEmpty) continue;
        final node = nodes[random.nextInt(nodes.length)];
        final after = before.replaced(node.id, const []);
        bool gone(DocLeaf leaf) => after.nodeOf(leaf.id) == null;

        expect(
          before.nodesNotIn(after).whereType<DocLeaf>().where(gone),
          leavesIn(before.root).where(gone),
          reason: text,
        );
      }
    });
  });
}
