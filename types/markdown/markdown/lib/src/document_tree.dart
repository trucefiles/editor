import 'package:truce_core/truce_core.dart' show splitLines;

import 'read/document_reading.dart';
import 'tree/blocks.dart';
import 'tree/document_style.dart';

/// A Markdown document: its lines as in the file, and the block tree read
/// from them.
///
/// The text's lines are broken by `\n`, as the file's text model gives
/// them (it keeps the file's own line breaks and byte order mark); a
/// `\r\n` or lone `\r` breaks a line too, as CommonMark reads them. The
/// tree is what CommonMark and GitHub Flavored Markdown read in the
/// lines, with front matter as the one extension. Blocks name their lines
/// by index. Immutable: a changed text is read anew. Questions are
/// lookups, derived once per tree when first asked.
final class DocumentTree {
  DocumentTree._(this.text, this.lines) : _reading = readDocument(lines);

  /// The tree [text] reads as.
  factory DocumentTree.read(String text) =>
      DocumentTree._(text, splitLines(text));

  /// The text it was read from.
  final String text;

  /// Its lines, without their breaks; at least one.
  final List<String> lines;

  final DocumentReading _reading;

  RootBlock get root => _reading.root;

  /// The link reference definitions, by normalized label; the first of a
  /// label counts.
  Map<String, LinkDefinition> get definitions => _reading.definitions;

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
