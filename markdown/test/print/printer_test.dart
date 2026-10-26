import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_markdown/src/doc/definitions.dart';
import 'package:truce_markdown/src/doc/doc_nodes.dart';
import 'package:truce_markdown/src/doc/doc_tree.dart';
import 'package:truce_markdown/src/doc/load.dart';
import 'package:truce_markdown/src/doc/normalized.dart';
import 'package:truce_markdown/src/print/printer.dart';
import 'package:truce_markdown/src/print/text_layouts.dart';
import 'package:truce_markdown/src/tree/blocks.dart';
import 'package:truce_markdown/src/tree/inlines.dart';
import 'package:truce_markdown/src/visible/formatting.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';

import '../spec/spec_examples.dart';
import '../support/doc_dump.dart';
import '../support/document_corpus.dart';

void main() {
  final texts = [
    ...documentCorpus,
    for (final spec in ['commonmark-0.31.2.txt', 'gfm-0.29-extensions.txt'])
      for (final example in specExamples(spec))
        example.markdown.replaceFirst(RegExp(r'\n$'), ''),
  ];

  group('a print', () {
    test('of a document as read is its text', () {
      for (final text in texts) {
        final loaded = loadMarkdown(text);
        expect(printMarkdown(loaded.doc, loaded.origin).text, text);
      }
    });

    test('keeps the bytes of every block as read, under a changed root', () {
      for (final text in [...texts, for (final text in texts) '$text\n']) {
        final loaded = loadMarkdown(text);
        final root = loaded.doc.root;
        final doc = DocTree(
          root.withChildren(root.children),
          nextId: loaded.doc.nextId,
        );
        expect(printMarkdown(doc, loaded.origin).text, text, reason: text);
      }
    });

    test('writes each text as read as it is', () {
      // What keeps a block as read sound wherever it is printed anew.
      for (final text in texts) {
        final (:doc, :origin) = loadMarkdown(text);
        final layouts = TextLayouts(
          definitions: definitionsOf(doc.root),
          style: origin.markdown.style,
        );
        for (final node in nodesIn(doc.root).whereType<TextNode>()) {
          expect(
            dumpText(layouts.writable(node).text),
            dumpText(node.text),
            reason: text,
          );
        }
      }
    });

    test('reads back as its writable form, after any edits', () {
      final crlf = [
        for (final text in texts.take(80)) text.replaceAll('\n', '\r\n'),
      ];
      for (final (index, text) in [...texts, ...crlf].indexed) {
        final random = Random(index + 1000 * _seed);
        final loaded = loadMarkdown(text);
        var doc = loaded.doc;
        for (var step = 0; step < 6; step++) {
          doc = _randomEdit(random, doc);
          final printed = printMarkdown(doc, loaded.origin).text;
          final reread = loadMarkdown(printed);
          expect(
            dumpDoc(writableMarkdown(reread.doc, reread.origin).root),
            dumpDoc(writableMarkdown(doc, loaded.origin).root),
            reason: 'source: ${_show(text)}\nprinted: ${_show(printed)}',
          );
          expect(
            printMarkdown(doc, loaded.origin).text,
            printed,
            reason: 'not deterministic',
          );
          if (text.contains('\r\n') && !text.contains(RegExp('[^\r]\n'))) {
            expect(
              printed.contains(RegExp('(^|[^\r])\n')),
              isFalse,
              reason: 'a line ending not the document\'s: ${_show(printed)}',
            );
          }
        }
      }
    });
  });

  group('prints', () {
    String edited(String text, DocTree Function(DocTree doc) edit) {
      final loaded = loadMarkdown(text);
      return printMarkdown(edit(loaded.doc), loaded.origin).text;
    }

    DocBlock nth<T extends DocBlock>(DocTree doc, int index) =>
        nodesIn(doc.root).whereType<T>().elementAt(index);

    TextNode retexted(TextNode node, String text) =>
        node.withText(VisibleText([TextPiece(text)]));

    test('an edited paragraph alone, the rest byte for byte', () {
      expect(
        edited('# A  \r\n\r\nold *x*\r\n\r\n* b\r\n', (doc) {
          final paragraph = nth<ParagraphNode>(doc, 0) as TextNode;
          return doc.withNode(retexted(paragraph, 'new'));
        }),
        '# A  \r\n\r\nnew\r\n\r\n* b\r\n',
      );
    });

    test('a toggled box with the rest of its item kept', () {
      expect(
        edited('- [ ] a\n  more\n- [X] b', (doc) {
          final item = nth<ItemNode>(doc, 0) as ItemNode;
          return doc.withNode(item.withBox(true));
        }),
        '- [x] a\n  more\n- [X] b',
      );
    });

    test('a list without the empty item Enter split it at', () {
      expect(
        edited('1. a\n2. b\n3. c', (doc) {
          final list = nth<ListNode>(doc, 0) as ListNode;
          final fresh = doc.freshIds;
          return doc.replaced(list.id, [
            ListNode(
              fresh.take(),
              list.items.take(1).toList(),
              kind: list.kind,
              source: list.source,
            ),
            emptyParagraph(fresh),
            ListNode(
              fresh.take(),
              list.items.skip(2).toList(),
              kind: list.kind,
              start: 2,
            ),
          ], fresh: fresh);
        }),
        '1. a\n2. c',
      );
    });

    test('a new paragraph after HTML apart from it', () {
      expect(
        edited('<div>\nx\n</div>', (doc) {
          final html = nth<RawNode>(doc, 0);
          final fresh = doc.freshIds;
          return doc.replaced(html.id, [
            html,
            ParagraphNode(fresh.take(), VisibleText([TextPiece('after')])),
          ], fresh: fresh);
        }),
        '<div>\nx\n</div>\n\nafter',
      );
    });

    test('renumbered items with their lines kept', () {
      expect(
        edited('1. a\n2. b\n   more\n3. c', (doc) {
          final list = nth<ListNode>(doc, 0) as ListNode;
          return doc.withNode(list.withChildren(list.items.skip(1).toList()));
        }),
        '1. b\n   more\n2. c',
      );
    });

    test('a wrapped paragraph reflowed from the changed line', () {
      final words = List.generate(40, (index) => 'word$index');
      final wrapped = [
        words.take(10).join(' '),
        words.skip(10).take(10).join(' '),
        words.skip(20).take(10).join(' '),
        words.skip(30).join(' '),
      ].join('\n');
      final printed = edited(wrapped, (doc) {
        final paragraph = nth<ParagraphNode>(doc, 0) as TextNode;
        final text = paragraph.text;
        final at = text.text.indexOf('word11');
        return doc.withNode(
          paragraph.withText(
            text.replaced(at, at, VisibleText([TextPiece('new ')])),
          ),
        );
      }).split('\n');
      expect(printed.first, wrapped.split('\n').first);
      expect(printed.last, wrapped.split('\n').last);
      expect(printed[1], startsWith('word10 new word11'));
    });

    TextNode retextedWith(TextNode node, List<VisiblePiece> pieces) =>
        node.withText(VisibleText(pieces));

    DocTree quoted(DocTree doc, DocBlock node) {
      final fresh = doc.freshIds;
      return normalized(
        doc.replaced(node.id, [
          QuoteNode(fresh.take(), [node]),
        ], fresh: fresh),
        fresh,
      );
    }

    HeadingNode leveled(HeadingNode heading, int level) => HeadingNode(
      heading.id,
      heading.text,
      level: level,
      source: heading.source,
    );

    test('a list toggled to the kind of the list before it as one', () {
      expect(
        edited('- a\n\n1. b', (doc) {
          final list = nth<ListNode>(doc, 1) as ListNode;
          return doc.withNode(list.withKind(ListKind.bullet));
        }),
        '- a\n- b',
      );
    });

    test('a list out of the last item of the list before it', () {
      expect(
        edited('10) foo\n   - bar', (doc) {
          final list = nth<ListNode>(doc, 0) as ListNode;
          return doc.withNode(
            ListNode(
              list.id,
              list.items,
              kind: list.kind,
              start: 9,
              source: list.source,
            ),
          );
        }),
        '9) foo\n- bar',
      );
    });

    test('its containers\' marks on blank lines that need them', () {
      expect(
        edited(
          '- Foo\n\n      bar\n\n\n      baz',
          (doc) => quoted(doc, nth<CodeNode>(doc, 0)),
        ),
        '- Foo\n\n  >     bar\n  >\n  >\n  >     baz',
      );
    });

    test('headings ATX unless setext and level 1 or 2', () {
      expect(
        edited('Title\n=====\n\n# T', (doc) {
          final setext = nth<HeadingNode>(doc, 0) as HeadingNode;
          final atx = nth<HeadingNode>(doc, 1) as HeadingNode;
          return doc.withNode(leveled(setext, 3)).withNode(leveled(atx, 2));
        }),
        '### Title\n\n## T',
      );
      expect(
        edited('Title\n=====', (doc) {
          return doc.withNode(
            leveled(nth<HeadingNode>(doc, 0) as HeadingNode, 2),
          );
        }),
        'Title\n-----',
      );
    });

    test('a fence longer than the code\'s own fences', () {
      expect(
        edited('```\na\n```', (doc) {
          final code = nth<CodeNode>(doc, 0) as CodeNode;
          return doc.withNode(code.withCode('a\n```'));
        }),
        '````\na\n```\n````',
      );
    });

    test('an empty item\'s box with the space after it', () {
      expect(
        edited('- [ ] a\n- b', (doc) {
          final paragraph = nth<ParagraphNode>(doc, 0) as TextNode;
          return doc.withNode(retextedWith(paragraph, []));
        }),
        '- [ ] \n- b',
      );
    });

    test('a byte order mark and final newline as read', () {
      expect(
        edited('\uFEFFa\n', (doc) {
          final paragraph = nth<ParagraphNode>(doc, 0) as TextNode;
          return doc.withNode(retexted(paragraph, 'b'));
        }),
        '\uFEFFb\n',
      );
    });

    test('a reference link inline once its definition is gone', () {
      expect(
        edited('[x]\n\n[x]: /u', (doc) {
          final definitions = nth<RawNode>(doc, 0);
          final fresh = doc.freshIds;
          return normalized(
            doc.replaced(definitions.id, const [], fresh: fresh),
            fresh,
          );
        }),
        '[x](/u)',
      );
    });

    test('a tag first in a paragraph off a line of its own', () {
      final tag = '<a title="${'x' * 110}">';
      final printed = edited('a', (doc) {
        final paragraph = nth<ParagraphNode>(doc, 0) as TextNode;
        return doc.withNode(
          retextedWith(paragraph, [
            ObjectPiece(HtmlInline(tag)),
            TextPiece(' word word'),
          ]),
        );
      });
      expect(printed, '$tag word\nword');
    });

    TextNode appended(TextNode node, String text) =>
        node.withText(VisibleText([...node.text.pieces, TextPiece(text)]));

    test('inline HTML with its own line ends', () {
      expect(
        edited('<a b="c"\nd="e" />', (doc) {
          final paragraph = nth<ParagraphNode>(doc, 0) as TextNode;
          return doc.withNode(appended(paragraph, ' x'));
        }),
        '<a b="c"\nd="e" /> x',
      );
    });

    test('emphasis nested where the rule of three keeps it apart', () {
      expect(
        edited('*foo**bar**baz*', (doc) {
          final paragraph = nth<ParagraphNode>(doc, 0) as TextNode;
          return doc.withNode(appended(paragraph, '!'));
        }),
        '*foo**bar**baz*!',
      );
    });

    test('code in an item without spaces on its blank lines', () {
      final loaded = loadMarkdown('- a');
      final item = nth<ItemNode>(loaded.doc, 0) as ItemNode;
      final code = CodeNode(loaded.doc.freshIds.take(), 'x\n  \ny');
      final doc = loaded.doc.withNode(item.withChildren([code]));
      expect(
        dumpDoc(writableMarkdown(doc, loaded.origin).root),
        contains('code "" "x\\n\\ny"'),
      );
      expect(
        printMarkdown(doc, loaded.origin).text,
        '- ```\n  x\n\n  y\n  ```',
      );
    });

    test('each printed block\'s lines', () {
      final loaded = loadMarkdown('a\n\nb\nc');
      final paragraphs = nodesIn(loaded.doc.root).whereType<ParagraphNode>();
      final doc = loaded.doc.withNode(retexted(paragraphs.first, 'x'));
      expect(printMarkdown(doc, loaded.origin).lines, {
        paragraphs.first.id: (first: 0, last: 0),
        paragraphs.last.id: (first: 2, last: 3),
      });
    });
  });
}

/// Another seed for a longer run: `FUZZ_SEED=7 dart test ...`.
final _seed = int.parse(Platform.environment['FUZZ_SEED'] ?? '0');

String _show(String text) =>
    text.replaceAll('\r', r'\r').replaceAll('\n', r'\n');

const _words = [
  'a',
  'word',
  ' ',
  '*',
  '_',
  '#',
  '- ',
  '1. ',
  '> ',
  '`',
  '<b>',
  '[x]',
  '&amp;',
  'www.x.io',
];

/// [doc] with one random edit, kept normalized.
DocTree _randomEdit(Random random, DocTree doc) {
  final fresh = doc.freshIds;
  final nodes = nodesIn(doc.root).where((node) => node is! DocRoot).toList();
  if (nodes.isEmpty) return doc;
  final node = nodes[random.nextInt(nodes.length)];
  VisibleText words() => VisibleText([
    for (var count = random.nextInt(3) + 1; count > 0; count--)
      TextPiece(
        _words[random.nextInt(_words.length)],
        Formatting({
          if (random.nextInt(4) == 0) TextFormat.strong,
          if (random.nextInt(4) == 0) TextFormat.emphasis,
        }),
      ),
  ]);
  final edited = switch ((random.nextInt(9), node)) {
    (0 || 1, final TextNode text) => doc.withNode(
      text.withText(
        text.text.replaced(
          random.nextInt(text.text.length + 1),
          random.nextInt(text.text.length + 1).clamp(0, text.text.length),
          words(),
        ),
      ),
    ),
    (2, final ItemNode item) => doc.withNode(
      item.withBox(const [null, true, false][random.nextInt(3)]),
    ),
    (3, _)
        when doc.parentOf(node.id) is! ListNode &&
            !(node is RawNode && takesInTheRest(node)) =>
      doc.replaced(node.id, [
        node,
        ParagraphNode(fresh.take(), words()),
      ], fresh: fresh),
    (4, _) => doc.replaced(node.id, const [], fresh: fresh),
    (5, final ListNode list) => doc.withNode(
      list.withKind(
        list.kind == ListKind.bullet ? ListKind.numbered : ListKind.bullet,
      ),
    ),
    (6, final ItemNode item) => switch (doc.parentOf(item.id)!) {
      final ListNode list => doc.withNode(
        list.withChildren([
          ...list.items.where((other) => other != item),
          item,
        ]),
      ),
      _ => doc,
    },
    (7, _) when doc.parentOf(node.id) is! ListNode && node is! RawNode =>
      doc.replaced(node.id, [
        QuoteNode(fresh.take(), [node]),
      ], fresh: fresh),
    (8, final HeadingNode heading) => doc.withNode(
      HeadingNode(
        heading.id,
        heading.text,
        level: random.nextInt(6) + 1,
        source: heading.source,
      ),
    ),
    (8, final CodeNode code) => doc.withNode(
      code.withCode('${code.code}\nmore'),
    ),
    _ => doc,
  };
  return normalized(edited, fresh);
}
