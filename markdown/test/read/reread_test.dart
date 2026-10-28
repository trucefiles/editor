import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart' show LineChange;
import 'package:truce_markdown/src/document_tree.dart';
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
        final edited = _randomEdit(random, tree);
        final changed = tree.withText(edited);
        final reason = 'text: ${_show(tree.text)}\nedited: ${_show(edited)}';
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
        LineChange(10, 11, [
          (id: tree.lines[10].id, text: '- item ten', ending: '\n'),
        ]),
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
      final changed = tree.changed(
        LineChange(2, 3, [(id: null, text: 'x', ending: '')]),
      );
      expect(changed.root.children[1].id, paragraph.id);
    });

    test('keeps the ids of the lines it keeps', () {
      final tree = DocumentTree.read('a\nb\nc');
      final changed = tree.withText('a\nB\nc');
      expect(changed.lines.first.id, tree.lines.first.id);
      expect(changed.lines.last.id, tree.lines.last.id);
      expect(changed.lines[1].id, isNot(tree.lines[1].id));
    });

    test('keeps each line\'s ending, and a byte order mark', () {
      final tree = DocumentTree.read('\uFEFFa\r\nb\nc');
      final changed = tree.withText('\uFEFFa\r\nB\nc');
      expect(changed.text, '\uFEFFa\r\nB\nc');
      expect(changed.lines.first.id, tree.lines.first.id);
      expect(tree.withText('a\nb').text, 'a\nb');
    });

    test('reads front matter that a change closes', () {
      final tree = DocumentTree.read('---\na: b\ntext');
      final changed = tree.changed(
        LineChange(2, 2, [(id: null, text: '---', ending: '\n')]),
      );
      expect(changed.root.children.first, isA<FrontMatterBlock>());
    });

    test('re-parses text when link definitions change', () {
      final tree = DocumentTree.read('[x]\n\nmore\n\n[y]: /url');
      final changed = tree.changed(
        LineChange(4, 5, [
          (id: tree.lines[4].id, text: '[x]: /url', ending: ''),
        ]),
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

/// [tree]'s text with a random change to its lines: one replaced,
/// put in, removed, or edited by a character, or a few replaced.
String _randomEdit(Random random, DocumentTree tree) {
  final lines = [for (final line in tree.lines) line.text];
  final count = lines.length;
  final at = random.nextInt(count + 1);
  String fragment() => _fragments[random.nextInt(_fragments.length)];
  switch (random.nextInt(5)) {
    case 0 when at < count:
      lines[at] = fragment();
    case 1:
      lines.insert(at, fragment());
    case 2 when at < count && count > 1:
      lines.removeAt(at);
    case 3 when at < count:
      final line = lines[at];
      final offset = random.nextInt(line.length + 1);
      final char = _characters[random.nextInt(_characters.length)];
      lines[at] = random.nextBool() || line.isEmpty
          ? line.replaceRange(offset, offset, char)
          : line.replaceRange(
              offset.clamp(0, line.length - 1),
              offset.clamp(0, line.length - 1) + 1,
              '',
            );
    default:
      final end = (at + random.nextInt(3)).clamp(at, count);
      final added = random.nextInt(3) + (end - at == count ? 1 : 0);
      lines.replaceRange(at, end, [
        for (var index = added; index > 0; index--) fragment(),
      ]);
  }
  return [
    for (final (index, line) in lines.indexed) ...[
      line,
      if (index < lines.length - 1) _ending(random),
    ],
  ].join();
}

String _ending(Random random) => const ['\n', '\r\n', '\r'][random.nextInt(3)];

String _show(String text) =>
    text.replaceAll('\r', r'\r').replaceAll('\n', r'\n');
