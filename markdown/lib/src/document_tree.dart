import 'package:collection/collection.dart';

import 'lines/line.dart';
import 'lines/line_change.dart';
import 'lines/line_endings.dart';
import 'read/document_reading.dart';
import 'tree/blocks.dart';
import 'tree/document_style.dart';

/// A Markdown document: its lines as in the file, and the block tree read
/// from them.
///
/// Lines are the bytes, each with its own line ending; the tree is what
/// CommonMark and GitHub Flavored Markdown read in them, with front matter
/// as the one extension. A byte order mark is kept apart from the lines.
/// Immutable: a change returns a new tree that reads again only from the
/// block before the change until the reading lines up with this one, and
/// keeps the rest. Lines and blocks keep their ids across changes. Ids
/// are unique among the trees changed from one [DocumentTree.read].
/// Questions are lookups, derived once per tree when first asked.
final class DocumentTree implements EarlierReading {
  DocumentTree._(
    List<Line> lines,
    DocumentReading reading,
    this._nextLineId, {
    required this.byteOrderMark,
  }) : lines = List.unmodifiable(lines),
       root = reading.root,
       definitions = Map.unmodifiable(reading.definitions),
       _nextBlockId = reading.nextBlockId;

  /// [text], with its lines ended by `\n`, `\r\n` or `\r`.
  factory DocumentTree.read(String text) {
    final bom = text.startsWith(byteOrderMarkCharacter);
    final lines = [
      for (final (index, line) in splitLines(
        bom ? text.substring(1) : text,
      ).indexed)
        Line(LineId(index), line.text, line.ending),
    ];
    return DocumentTree._(
      lines,
      readDocument(lines),
      lines.length,
      byteOrderMark: bom,
    );
  }

  @override
  final List<Line> lines;

  /// Whether the text starts with a byte order mark.
  final bool byteOrderMark;

  @override
  final RootBlock root;

  /// The link reference definitions, by normalized label; the first of a
  /// label counts.
  @override
  final Map<String, LinkDefinition> definitions;

  final int _nextLineId;
  final int _nextBlockId;

  late final String text = [
    if (byteOrderMark) byteOrderMarkCharacter,
    for (final line in lines) ...[line.text, line.ending],
  ].join();

  /// The text after its front matter, for readers that don't know front
  /// matter; the whole text if it has none.
  late final String textAfterFrontMatter = switch (root.children.firstOrNull) {
    final FrontMatterBlock front => [
      for (final line in lines.skip(front.lines.length)) ...[
        line.text,
        line.ending,
      ],
    ].join(),
    _ => text,
  };

  /// The ending most of its lines have, for lines it gets.
  late final String lineEnding = dominantEnding(
    lines.map((line) => line.ending),
  );

  /// How the document writes what it holds, for new content.
  late final DocumentStyle style = DocumentStyle.of(root);

  /// This document with [change] made; a document keeps at least one line.
  DocumentTree changed(LineChange change) {
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
    assert(() {
      final endings = [
        ...lines.take(change.start).map((line) => line.ending),
        ...change.lines.map((line) => line.ending),
        ...lines.skip(change.end).map((line) => line.ending),
      ];
      return endings.last.isEmpty &&
          endings.take(endings.length - 1).every((e) => e.isNotEmpty);
    }(), 'every line but the last ends with a line ending');
    var nextLineId = _nextLineId;
    final added = [
      for (final line in change.lines)
        Line(line.id ?? LineId(nextLineId++), line.text, line.ending),
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
        nextBlockId: _nextBlockId,
      ),
      nextLineId,
      byteOrderMark: byteOrderMark,
    );
  }

  /// This document with [text] instead, e.g. after it was edited as text:
  /// the unchanged lines at its start and end keep their ids; all others
  /// are new lines.
  DocumentTree withText(String text) {
    final bom = text.startsWith(byteOrderMarkCharacter);
    final news = splitLines(bom ? text.substring(1) : text);
    final olds = [
      for (final line in lines) (text: line.text, ending: line.ending),
    ];
    final head = _sameAtStart(news, olds);
    final tail = _sameAtStart(
      news.skip(head).toList().reversed,
      olds.skip(head).toList().reversed,
    );
    final changed = this.changed(
      LineChange(head, olds.length - tail, [
        for (final line in news.sublist(head, news.length - tail))
          (id: null, text: line.text, ending: line.ending),
      ]),
    );
    return bom == byteOrderMark
        ? changed
        : DocumentTree._(
            changed.lines,
            (
              root: changed.root,
              definitions: changed.definitions,
              nextBlockId: changed._nextBlockId,
            ),
            changed._nextLineId,
            byteOrderMark: bom,
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
int _sameAtStart<T>(Iterable<T> a, Iterable<T> b) =>
    IterableZip([a, b]).takeWhile((pair) => pair[0] == pair[1]).length;
