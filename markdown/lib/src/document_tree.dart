import 'package:truce_core/truce_core.dart'
    show TextLine, byteOrderMarkCharacter, dominantEnding, splitLines;

import 'read/document_reading.dart';
import 'tree/blocks.dart';
import 'tree/document_style.dart';

/// A Markdown document: its lines as in the file, and the block tree read
/// from them.
///
/// Lines keep their own line endings, and a byte order mark is kept apart
/// from them; the tree is what CommonMark and GitHub Flavored Markdown
/// read in them, with front matter as the one extension. Blocks name
/// their lines by index. Immutable: a changed text is read anew.
/// Questions are lookups, derived once per tree when first asked.
final class DocumentTree {
  DocumentTree._(this.text, this.lines, {required this.byteOrderMark})
    : _reading = readDocument([for (final line in lines) line.text]);

  /// [text], with its lines ended by `\n`, `\r\n` or `\r`.
  factory DocumentTree.read(String text) {
    final mark = text.startsWith(byteOrderMarkCharacter);
    return DocumentTree._(
      text,
      splitLines(mark ? text.substring(1) : text),
      byteOrderMark: mark,
    );
  }

  /// The text it was read from.
  final String text;

  /// Its lines, at least one; the last one has no ending.
  final List<TextLine> lines;

  /// Whether the text starts with a byte order mark.
  final bool byteOrderMark;

  final DocumentReading _reading;

  RootBlock get root => _reading.root;

  /// The link reference definitions, by normalized label; the first of a
  /// label counts.
  Map<String, LinkDefinition> get definitions => _reading.definitions;

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

  /// Every leaf, in file order.
  late final List<LeafBlock> leaves = root.leaves.toList();

  late final Map<int, LeafBlock> _leafByLine = {
    for (final leaf in leaves)
      for (final line in leaf.lines) line.index: leaf,
  };

  /// The leaf line [index] is in; `null` for a blank line or an empty
  /// item's marker line.
  LeafBlock? leafOf(int index) => _leafByLine[index];

  late final _places = _Places(root);

  /// The block with [id] and the containers it is in; `null` if there is
  /// none.
  PlacedBlock? placeOf(BlockId id) => _places.byId[id];

  /// The block with [id]; `null` if there is none.
  Block? blockOf(BlockId id) => placeOf(id)?.block;

  /// The container [block] is in; `null` for the root.
  ContainerBlock? parentOf(Block block) => placeOf(block.id)?.path.lastOrNull;

  /// The blocks that start at line [index], outermost first: a leaf at its
  /// first line, an item at its marker line, a container at its first
  /// child's. A block read from the same paragraph as the one right
  /// before it (text after link definitions, a table after text) starts
  /// at none.
  List<PlacedBlock> startsAt(int index) => _places.starts[index] ?? const [];
}

/// Where every block of a tree is, found in one walk.
final class _Places {
  _Places(RootBlock root) {
    _walk(root, const [], starts: false);
  }

  final byId = <BlockId, PlacedBlock>{};
  final starts = <int, List<PlacedBlock>>{};

  void _walk(Block block, List<ContainerBlock> path, {required bool starts}) {
    final placed = (block: block, path: path);
    byId[block.id] = placed;
    if (block is! RootBlock && starts) {
      (this.starts[lineSpanOf(block).first] ??= []).add(placed);
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
      block.lines.first.index == before.lines.last.index + 1,
    _ => false,
  };
}
