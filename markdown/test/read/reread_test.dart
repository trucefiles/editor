import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/lines/line_change.dart';
import 'package:truce_markdown/src/read/block_freezer.dart';
import 'package:truce_markdown/src/tree/blocks.dart';

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

  test('a re-read reads as a whole read, after any edits', () {
    for (final (index, text) in texts.indexed) {
      final random = Random(index + 1000 * _seed);
      var tree = DocumentTree.read(text);
      for (var step = 0; step < 30; step++) {
        final change = _randomChange(random, tree);
        final changed = tree.changed(change);
        final reason = 'text: ${_show(tree.text)}\nchange: $change';
        expect(
          dumpTree(changed),
          dumpTree(DocumentTree.read(changed.text)),
          reason: reason,
        );
        final ids = idsIn(changed.root).toList();
        expect(ids.toSet().length, ids.length, reason: reason);
        tree = changed;
      }
    }
  });

  group('a re-read', () {
    test('keeps the blocks after the change', () {
      final tree = DocumentTree.read(
        [for (var item = 0; item < 50; item++) '- item $item'].join('\n'),
      );
      final list = tree.root.children.single as ListBlock;
      final changed = tree.changed(
        LineChange(10, 11, [(id: tree.lines[10].id, text: '- item ten')]),
      );
      final items = (changed.root.children.single as ListBlock).items;
      expect(changed.root.children.single.id, list.id);
      expect(items.skip(11), list.items.skip(11));
      expect(items.take(9), list.items.take(9));
      expect(items[10].id, list.items[10].id);
    });

    test('keeps the id of text read after link definitions', () {
      final tree = DocumentTree.read('[a]: /url\nbar\n');
      final paragraph = tree.root.children.last;
      final changed = tree.changed(LineChange(2, 3, [(id: null, text: 'x')]));
      expect(changed.root.children[1].id, paragraph.id);
    });

    test('takes planned ids for blocks read anew', () {
      final tree = DocumentTree.read('a');
      final fresh = tree.freshBlockIds.first;
      final changed = tree.changed(
        LineChange(0, 1, [(id: tree.lines.first.id, text: '# a')]),
        planned: {
          (BlockKind.heading, 0): [fresh],
        },
      );
      expect(changed.root.children.single.id, fresh);
      expect(changed.freshBlockIds.first, isNot(fresh));
    });

    test('keeps the ids of the lines it keeps', () {
      final tree = DocumentTree.read('a\nb\nc');
      final changed = tree.withText('a\nB\nc');
      expect(changed.lines.first.id, tree.lines.first.id);
      expect(changed.lines.last.id, tree.lines.last.id);
      expect(changed.lines[1].id, isNot(tree.lines[1].id));
    });

    test('reads front matter that a change closes', () {
      final tree = DocumentTree.read('---\na: b\ntext');
      final changed = tree.changed(LineChange(2, 2, [(id: null, text: '---')]));
      expect(changed.root.children.first, isA<FrontMatterBlock>());
    });

    test('re-parses text when link definitions change', () {
      final tree = DocumentTree.read('[x]\n\nmore\n\n[y]: /url');
      final changed = tree.changed(
        LineChange(4, 5, [(id: tree.lines[4].id, text: '[x]: /url')]),
      );
      expect(dumpTree(changed), dumpTree(DocumentTree.read(changed.text)));
    });
  });
}

/// Another seed for a longer run: `FUZZ_SEED=7 dart test ...`.
final _seed = int.parse(Platform.environment['FUZZ_SEED'] ?? '0');

const _fragments = [
  '',
  '   ',
  'text',
  'more text',
  '- ',
  '-',
  '- item',
  '* star',
  '+ plus',
  '- [ ] box',
  '- [x]',
  '  - sub',
  '    - deep',
  '1. one',
  '2) two',
  '> ',
  '> quote',
  '>> deep',
  '> - quoted item',
  '# heading',
  '## two',
  '===',
  '---',
  '***',
  '```',
  '~~~ info',
  '    code',
  '\tcode',
  '| a | b |',
  '|---|---|',
  '<div>',
  '</div>',
  '<!--',
  '-->',
  '[x]: /url',
  '[x]',
  '  lazy',
  '**bold**',
  'a  ',
  r'b\',
];

const _characters = r'-*_>#`[]()! 1.x|<\';

LineChange _randomChange(Random random, DocumentTree tree) {
  final count = tree.lines.length;
  final at = random.nextInt(count + 1);
  String fragment() => _fragments[random.nextInt(_fragments.length)];
  switch (random.nextInt(5)) {
    case 0 when at < count:
      return LineChange(at, at + 1, [
        (id: tree.lines[at].id, text: fragment()),
      ]);
    case 1:
      return LineChange(at, at, [(id: null, text: fragment())]);
    case 2 when at < count && count > 1:
      return LineChange(at, at + 1, const []);
    case 3 when at < count:
      final line = tree.lines[at];
      final offset = random.nextInt(line.text.length + 1);
      final char = _characters[random.nextInt(_characters.length)];
      final text = random.nextBool() || line.text.isEmpty
          ? line.text.replaceRange(offset, offset, char)
          : line.text.replaceRange(
              offset.clamp(0, line.text.length - 1),
              offset.clamp(0, line.text.length - 1) + 1,
              '',
            );
      return LineChange(at, at + 1, [(id: line.id, text: text)]);
    default:
      final end = (at + random.nextInt(3)).clamp(at, count);
      final added = random.nextInt(3) + (end - at == count ? 1 : 0);
      return LineChange(at, end, [
        for (var index = added; index > 0; index--)
          (id: null, text: fragment()),
      ]);
  }
}

String _show(String text) => text.replaceAll('\n', r'\n');
