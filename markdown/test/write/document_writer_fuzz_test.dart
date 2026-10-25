import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:truce_markdown/src/document_tree.dart';
import 'package:truce_markdown/src/tree/blocks.dart';
import 'package:truce_markdown/src/visible/formatting.dart';
import 'package:truce_markdown/src/visible/visible_text.dart';
import 'package:truce_markdown/src/write/block/block_writer.dart';
import 'package:truce_markdown/src/write/block/gaps.dart';
import 'package:truce_markdown/src/write/document_writer.dart';
import 'package:truce_markdown/src/write/draft.dart';
import 'package:truce_markdown/src/write/inline/inline_writing.dart';

import '../spec/spec_examples.dart';
import '../support/document_corpus.dart';

void main() {
  final documents = [
    ...documentCorpus,
    for (final spec in ['commonmark-0.31.2.txt', 'gfm-0.29-extensions.txt'])
      for (final example in specExamples(spec)) example.markdown,
  ];

  test('a draft that keeps every block writes the document as it was', () {
    for (final document in documents) {
      final tree = DocumentTree.read(document);
      final after = _written(
        tree,
        RootDraft(tree.root, tree.root.children.map(KeptDraft.new).toList()),
      );
      expect(after.text, document);
      expect(after.lines, tree.lines);
    }
  });

  test('a draft that restates every block writes the document as it was', () {
    for (final document in documents) {
      final tree = DocumentTree.read(document);
      final after = _written(
        tree,
        RootDraft(tree.root, tree.root.children.map(_restated).toList()),
      );
      expect(after.text, document, reason: document);
    }
  });

  test('random edits anywhere write what was drafted', () {
    for (final (index, document) in documents.indexed) {
      final random = Random(index + 1000 * _seed);
      var tree = DocumentTree.read(document);
      for (var step = 0; step < 12; step++) {
        final draft = _randomEdit(random, tree);
        if (draft == null || !_writable(tree, draft)) continue;
        tree = _written(tree, draft);
      }
    }
  });
}

/// [written], failing with the document and the draft where it throws.
DocumentTree _written(DocumentTree tree, RootDraft draft) {
  try {
    final after = written(tree, draft);
    expect(
      _shape(after.root),
      _shape(DocumentTree.read(after.text).root),
      reason: 'reads as a whole read would',
    );
    return after;
  } on Object catch (error) {
    final lines = writeLines(tree, draft).lines.map((line) => line.text);
    fail(
      'from:\n${tree.text}\n${_shape(tree.root)}\n---\n'
      'with ${draft.children.map(_describe)}\n---\nwrote:\n${lines.join('\n')}\n'
      '${_shape(DocumentTree.read(lines.join('\n')).root)}\n$error',
    );
  }
}

/// Whether [draft] is one a command could make: front matter stays
/// first, and no block follows one that takes in the rest.
bool _writable(DocumentTree tree, RootDraft draft) {
  final front = tree.root.children.whereType<FrontMatterBlock>();
  final first = draft.children.firstOrNull;
  return (front.isEmpty ||
          (first is KeptDraft && first.block is FrontMatterBlock)) &&
      draft.children
          .skip(1)
          .every(
            (child) => !(child is KeptDraft && child.block is FrontMatterBlock),
          ) &&
      _followable(draft.children);
}

bool _followable(List<Draft> drafts) => drafts.indexed.every(
  (entry) => switch (entry.$2) {
    KeptDraft(block: final LeafBlock leaf) =>
      entry.$1 == drafts.length - 1 || !takesInTheRest(leaf),
    KeptDraft(block: final ContainerBlock container) => _followable([
      for (final child in container.children) KeptDraft(child),
    ]),
    QuoteDraft(:final children) ||
    ItemDraft(:final children) => _followable(children),
    ListDraft(:final items) => _followable(items),
    _ => true,
  },
);

/// [block]'s kinds and lines, outermost first.
String _shape(Block block) => switch (block) {
  ContainerBlock(:final children) =>
    '${block.runtimeType}(${children.map(_shape).join(', ')})',
  LeafBlock(:final lines) =>
    '${block.runtimeType}${[for (final line in lines) line.text]}',
};

final _seed = int.parse(Platform.environment['FUZZ_SEED'] ?? '0');

String _describe(Draft draft) => switch (draft) {
  ListDraft(:final items, :final loose) =>
    'List(${draft.id}${loose ? ' loose' : ''})[${items.map(_describe).join(', ')}]',
  ItemDraft(:final children, :final checked) =>
    'Item(${draft.id} $checked)[${children.map(_describe).join(', ')}]',
  QuoteDraft(:final children) =>
    'Quote(${draft.id})[${children.map(_describe).join(', ')}]',
  KeptDraft(:final block) => 'Kept(${block.runtimeType} ${block.id})',
  TextDraft(:final level, :final text) =>
    'Text(${draft.id} $level "${text.text}")',
  CodeDraft() => 'Code(${draft.id})',
};

/// [tree] with one random edit in one of its containers; `null` where
/// the edit picked does not apply.
RootDraft? _randomEdit(Random random, DocumentTree tree) {
  final containers = [tree.root, ..._containersIn(tree.root)];
  final container = containers[random.nextInt(containers.length)];
  final fresh = tree.freshBlockIds.take(3).toList();
  final children = switch (container) {
    ListBlock(:final items) => _itemEdit(random, items, container, fresh),
    _ => _blockEdit(random, container.children, fresh),
  };
  if (children == null) return null;
  return RootDraft(tree.root, [
    for (final child in tree.root.children)
      _rebuilt(child, container, children),
  ]);
}

Iterable<ContainerBlock> _containersIn(ContainerBlock container) => container
    .children
    .whereType<ContainerBlock>()
    .expand((child) => [child, ..._containersIn(child)]);

/// [block] as a draft, with [children] in place of [target]'s.
Draft _rebuilt(Block block, ContainerBlock target, List<Draft> children) {
  if (block is! ContainerBlock || !idsIn(block).contains(target.id)) {
    return KeptDraft(block);
  }
  final inner = block.id == target.id
      ? children
      : [for (final child in block.children) _rebuilt(child, target, children)];
  return switch (block) {
    QuoteBlock() => QuoteDraft.of(block, inner),
    ListBlock() => ListDraft.of(block, inner),
    ItemBlock() => ItemDraft.of(block, inner),
    RootBlock() => throw StateError('the root is no child'),
  };
}

/// [blocks] after one edit: one moved, deleted, quoted or unquoted,
/// typed in, split, made a heading or a paragraph, or one added.
List<Draft>? _blockEdit(
  Random random,
  List<Block> blocks,
  List<BlockId> fresh,
) {
  if (blocks.isEmpty) return [TextDraft(fresh.first, _plain('new text'))];
  final at = random.nextInt(blocks.length);
  final kept = blocks.map(KeptDraft.new).toList();
  List<Draft> replaced(List<Draft> drafts) => [
    ...kept.take(at),
    ...drafts,
    ...kept.skip(at + 1),
  ];
  final block = blocks[at];
  // No edit leaves a container empty.
  final edit = random.nextInt(8);
  return switch ((edit, block)) {
    (0, _) => [
      ...kept.take(at),
      ...kept.skip(at + 1),
    ]..insert(random.nextInt(blocks.length), kept[at]),
    (1, _) when blocks.length > 1 => replaced([]),
    (2, _) => replaced([
      QuoteDraft(fresh.first, [kept[at]]),
    ]),
    (3, final QuoteBlock quote) => replaced(
      quote.children.map(KeptDraft.new).toList(),
    ),
    (4, final ParagraphBlock paragraph) => replaced([
      TextDraft(
        paragraph.id,
        visibleTextOf(paragraph.text) + _plain(' word'),
        from: [paragraph],
      ),
    ]),
    (5, final ParagraphBlock paragraph) => switch (_split(
      random,
      visibleTextOf(paragraph.text),
    )) {
      (final first, final second) => replaced([
        TextDraft(paragraph.id, first, from: [paragraph]),
        TextDraft(fresh.first, second),
      ]),
      null => null,
    },
    (6, final TextLeaf leaf)
        when !visibleTextOf(leaf.text).pieces
            .any((piece) => piece is! TextPiece && piece is! ObjectPiece) =>
      replaced([
        TextDraft(
          leaf.id,
          visibleTextOf(leaf.text),
          level: leaf is HeadingBlock ? null : random.nextInt(6) + 1,
          from: [leaf],
        ),
      ]),
    (6 || 7, _) => [
      ...kept.take(at + 1),
      TextDraft(fresh.first, _plain('new text')),
      ...kept.skip(at + 1),
    ],
    _ => null,
  };
}

/// [items] of [list] after one edit: one moved, deleted, its box
/// toggled, indented under the one above, or one added.
List<Draft>? _itemEdit(
  Random random,
  List<ItemBlock> items,
  ListBlock list,
  List<BlockId> fresh,
) {
  final at = random.nextInt(items.length);
  final kept = items.map(KeptDraft.new).toList();
  final item = items[at];
  return switch (random.nextInt(5)) {
    0 => [
      ...kept.take(at),
      ...kept.skip(at + 1),
    ]..insert(random.nextInt(items.length), kept[at]),
    1 when items.length > 1 => [...kept.take(at), ...kept.skip(at + 1)],
    2 => [
      ...kept.take(at),
      ItemDraft.of(
        item,
        item.children.map(KeptDraft.new).toList(),
        checked: switch (item.checked) {
          null => false,
          false => true,
          true => null,
        },
      ),
      ...kept.skip(at + 1),
    ],
    3 when at > 0 => [
      ...kept.take(at - 1),
      ItemDraft.of(items[at - 1], [
        ...items[at - 1].children.map(KeptDraft.new),
        ListDraft(fresh.first, [kept[at]], kind: list.kind, loose: list.loose),
      ]),
      ...kept.skip(at + 1),
    ],
    _ => [
      ...kept.take(at + 1),
      ItemDraft(fresh.first, [
        TextDraft(fresh[1], _plain('new item')),
      ], checked: item.checked),
      ...kept.skip(at + 1),
    ],
  };
}

/// [text] split in two at a space between words; `null` if it has none.
(VisibleText, VisibleText)? _split(Random random, VisibleText text) {
  final spaces = [
    for (final match in RegExp(r'(?<=\w) (?=\w)').allMatches(text.text))
      match.start,
  ];
  if (spaces.isEmpty) return null;
  final at = spaces[random.nextInt(spaces.length)];
  final halves = (
    text.replaced(at, text.length, VisibleText.empty),
    text.replaced(0, at + 1, VisibleText.empty),
  );
  return canWrite(halves.$1) && canWrite(halves.$2) ? halves : null;
}

Draft _restated(Block block) => switch (block) {
  QuoteBlock() => QuoteDraft.of(block, block.children.map(_restated).toList()),
  ListBlock() => ListDraft.of(block, block.items.map(_restated).toList()),
  ItemBlock() => ItemDraft.of(block, block.children.map(_restated).toList()),
  ParagraphBlock(:final text) => TextDraft(
    block.id,
    visibleTextOf(text),
    from: [block],
  ),
  HeadingBlock(:final text, :final level) => TextDraft(
    block.id,
    visibleTextOf(text),
    level: level,
    from: [block],
  ),
  CodeBlock(:final code) => CodeDraft(block, code),
  _ => asDraft(block),
};

VisibleText _plain(String text) =>
    VisibleText([TextPiece(text, Formatting.plain)]);
