import 'package:truce_core/truce_core.dart'
    show EditableLines, Line, LineChange, LineId, TextLines;

import 'read/document_reading.dart';
import 'tree/blocks.dart';
import 'tree/document_style.dart';

/// A Markdown document: its lines as in the file, and the block tree read
/// from them.
///
/// Lines are the bytes, each with its own line ending ([TextLines]); the
/// tree is what CommonMark and GitHub Flavored Markdown read in them, with
/// front matter as the one extension. Immutable: a change returns a new
/// tree that reads again only from the block before the change until the
/// reading lines up with this one, and keeps the rest. Lines and blocks
/// keep their ids across changes. Ids are unique among the trees changed
/// from one [DocumentTree.read]. Questions are lookups, derived once per
/// tree when first asked.
final class DocumentTree
    implements EarlierReading, EditableLines<DocumentTree> {
  DocumentTree._(this._lines, DocumentReading reading)
    : root = reading.root,
      definitions = Map.unmodifiable(reading.definitions),
      _nextBlockId = reading.nextBlockId;

  /// [text], with its lines ended by `\n`, `\r\n` or `\r`.
  factory DocumentTree.read(String text) {
    final lines = TextLines.read(text);
    return DocumentTree._(lines, readDocument(lines.lines));
  }

  final TextLines _lines;

  @override
  List<Line> get lines => _lines.lines;

  /// Whether the text starts with a byte order mark.
  bool get byteOrderMark => _lines.byteOrderMark;

  @override
  final RootBlock root;

  /// The link reference definitions, by normalized label; the first of a
  /// label counts.
  @override
  final Map<String, LinkDefinition> definitions;

  final int _nextBlockId;

  @override
  String get text => _lines.text;

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
  String get lineEnding => _lines.lineEnding;

  /// How the document writes what it holds, for new content.
  late final DocumentStyle style = DocumentStyle.of(root);

  /// This document with [change] made; a document keeps at least one line.
  DocumentTree changed(LineChange change) {
    final next = _lines.changed(change);
    return DocumentTree._(
      next,
      rereadDocument(
        this,
        next.lines,
        start: change.start,
        end: change.end,
        count: change.lines.length,
        nextBlockId: _nextBlockId,
      ),
    );
  }

  /// This document with its lines from [start] to [end] replaced by
  /// [lines], as a line editor holds them (see [TextLines.changeOf]).
  @override
  DocumentTree withLines(
    int start,
    int end,
    List<({LineId? id, String text})> lines,
  ) => changed(_lines.changeOf(start, end, lines));

  /// This document with [text] instead, e.g. after it was edited as text
  /// (see [TextLines.changeTo]).
  @override
  DocumentTree withText(String text) {
    final changed = this.changed(_lines.changeTo(text));
    final lines = changed._lines.withMarkOf(text);
    return identical(lines, changed._lines)
        ? changed
        : DocumentTree._(lines, (
            root: changed.root,
            definitions: changed.definitions,
            nextBlockId: changed._nextBlockId,
          ));
  }

  @override
  int indexOf(LineId id) => _lines.indexOf(id);

  /// The line [id]; `null` if there is none.
  Line? lineOf(LineId id) => _lines.lineOf(id);

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
