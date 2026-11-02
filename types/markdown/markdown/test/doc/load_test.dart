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
  });
}
