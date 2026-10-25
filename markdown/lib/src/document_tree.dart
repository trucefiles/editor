import 'package:collection/collection.dart';

import 'lines/line.dart';
import 'lines/line_change.dart';
import 'read/block_freezer.dart';
import 'read/document_reading.dart';
import 'tree/blocks.dart';
import 'tree/document_style.dart';

/// A document: its lines as in the file, and the block tree read from them.
///
/// Lines are the bytes; the tree is what CommonMark and GitHub Flavored
/// Markdown read in them, with front matter as the one extension.
/// Immutable: a change returns a new tree that reads again only from the
/// block before the change until the reading lines up with this one, and
/// keeps the rest. Lines and blocks keep their ids across changes. Ids
/// are unique among the trees changed from one [DocumentTree.read].
/// Questions are lookups, derived once per tree when first asked.
final class DocumentTree implements EarlierReading {
  DocumentTree._(List<Line> lines, DocumentReading reading, this._nextLineId)
    : lines = List.unmodifiable(lines),
      root = reading.root,
      definitions = Map.unmodifiable(reading.definitions),
      _nextBlockId = reading.nextBlockId;

  /// [text] with `\n` line breaks.
  factory DocumentTree.read(String text) {
    final lines = [
      for (final (index, line) in text.split('\n').indexed)
        Line(LineId(index), line),
    ];
    return DocumentTree._(lines, readDocument(lines), lines.length);
  }

  @override
  final List<Line> lines;

  @override
  final RootBlock root;

  /// The link reference definitions, by normalized label; the first of a
  /// label counts.
  @override
  final Map<String, LinkDefinition> definitions;

  final int _nextLineId;
  final int _nextBlockId;

  String get text => lines.map((line) => line.text).join('\n');

  /// How the document writes what it holds, for new content.
  late final DocumentStyle style = DocumentStyle.of(root);

  /// Ids no block of this document or the documents it was changed from has, in
  /// the order new blocks take them.
  Iterable<BlockId> get freshBlockIds sync* {
    for (var id = _nextBlockId; ; id++) {
      yield BlockId(id);
    }
  }

  /// This document with [change] made; a document keeps at least one line.
  /// Blocks read anew from its lines take their [planned] ids, by kind
  /// and line (index among the changed document's lines): ids of its blocks,
  /// or the first of its [freshBlockIds].
  DocumentTree changed(
    LineChange change, {
    Map<(BlockKind, int), List<BlockId>> planned = const {},
  }) {
    assert(
      change.lines.isNotEmpty || change.end - change.start < lines.length,
      'a change leaves a document without lines',
    );
    assert(() {
      final kept = change.lines.map((line) => line.id).nonNulls.toList();
      final others = {
        for (final line in [
          ...lines.take(change.start),
          ...lines.skip(change.end),
        ])
          line.id,
      };
      return kept.toSet().length == kept.length && !kept.any(others.contains);
    }(), 'line ids stay unique');
    var nextLineId = _nextLineId;
    final added = [
      for (final line in change.lines)
        Line(line.id ?? LineId(nextLineId++), line.text),
    ];
    final newLines = [
      ...lines.take(change.start),
      ...added,
      ...lines.skip(change.end),
    ];
    return DocumentTree._(
      newLines,
      rereadDocument(
        this,
        newLines,
        start: change.start,
        end: change.end,
        count: added.length,
        nextBlockId: _nextBlockId + _freshTaken(planned),
        planned: {
          for (final MapEntry(key: (kind, index), :value) in planned.entries)
            (kind, newLines[index].id): value,
        },
      ),
      nextLineId,
    );
  }

  /// How many of the [freshBlockIds] [planned] takes.
  int _freshTaken(Map<(BlockKind, int), List<BlockId>> planned) {
    final ids = planned.values.flattened.toSet();
    final taken =
        freshBlockIds.take(ids.length).toList().lastIndexWhere(ids.contains) +
        1;
    assert(
      ids.every(
        (id) => blockOf(id) != null || freshBlockIds.take(taken).contains(id),
      ),
      'planned ids are the document\'s or fresh ones',
    );
    return taken;
  }

  /// This document with [text] instead, e.g. after it changed elsewhere: the
  /// unchanged lines at its start and end keep their ids; all others are
  /// new lines.
  DocumentTree withText(String text) {
    final texts = text.split('\n');
    final olds = [for (final line in lines) line.text];
    final head = _sameAtStart(texts, olds);
    final tail = _sameAtStart(
      texts.skip(head).toList().reversed,
      olds.skip(head).toList().reversed,
    );
    return changed(
      LineChange(head, olds.length - tail, [
        for (final line in texts.sublist(head, texts.length - tail))
          (id: null, text: line),
      ]),
    );
  }

  late final Map<LineId, int> _indexes = {
    for (final (index, line) in lines.indexed) line.id: index,
  };

  @override
  int indexOf(LineId id) =>
      _indexes[id] ?? (throw ArgumentError.value(id, 'id', 'no such line'));

  /// The line [id]; `null` if there is none.
  Line? lineOf(LineId id) => switch (_indexes[id]) {
    final index? => lines[index],
    null => null,
  };

  /// Every leaf, in file order.
  late final List<LeafBlock> leaves = root.leaves.toList();

  late final Map<LineId, LeafBlock> _leafByLine = {
    for (final leaf in leaves)
      for (final line in leaf.lines) line.id: leaf,
  };

  /// The leaf line [id] is in; `null` for a blank line or an empty
  /// item's marker line.
  LeafBlock? leafOf(LineId id) => _leafByLine[id];

  late final _places = _Places(root, indexOf);

  /// The block with [id] and the containers it is in; `null` if there is
  /// none.
  PlacedBlock? placeOf(BlockId id) => _places.byId[id];

  /// The block with [id]; `null` if there is none.
  Block? blockOf(BlockId id) => placeOf(id)?.block;

  /// The container [block] is in; `null` for the root.
  ContainerBlock? parentOf(Block block) => placeOf(block.id)?.path.lastOrNull;

  @override
  List<PlacedBlock> startsAt(LineId id) => _places.starts[id] ?? const [];

  @override
  List<Block> firstAt(LineId id) => _places.firsts[id] ?? const [];
}

/// Where every block of a tree is, found in one walk.
final class _Places {
  _Places(RootBlock root, this._indexOf) {
    _walk(root, const [], starts: false);
  }

  final int Function(LineId id) _indexOf;
  final byId = <BlockId, PlacedBlock>{};
  final starts = <LineId, List<PlacedBlock>>{};
  final firsts = <LineId, List<Block>>{};

  void _walk(Block block, List<ContainerBlock> path, {required bool starts}) {
    final placed = (block: block, path: path);
    byId[block.id] = placed;
    if (block is! RootBlock) {
      final first = lineSpanOf(block).first;
      if (starts) (this.starts[first] ??= []).add(placed);
      (firsts[first] ??= []).add(block);
    }
    if (block is ContainerBlock) {
      final inner = [...path, block];
      for (final (index, child) in block.children.indexed) {
        _walk(
          child,
          inner,
          starts: index == 0 || !_continues(block.children[index - 1], child),
        );
      }
    }
  }

  /// Whether [block] is read from the same paragraph as [before], so it
  /// does not start at its first line: text right after the link
  /// definitions at a paragraph's start, or a table whose header was the
  /// paragraph's last line.
  bool _continues(Block before, Block block) => switch ((before, block)) {
    (final LeafBlock before, final LeafBlock block)
        when (before is DefinitionsBlock || before is ParagraphBlock) &&
            (block is TextLeaf || block is TableBlock) =>
      _indexOf(block.lines.first.id) == _indexOf(before.lines.last.id) + 1,
    _ => false,
  };
}

/// How many items [a] and [b] have equal at their start.
int _sameAtStart(Iterable<String> a, Iterable<String> b) =>
    IterableZip([a, b]).takeWhile((pair) => pair[0] == pair[1]).length;
