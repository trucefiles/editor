import '../document_tree.dart';
import '../read/document_reading.dart';
import '../tree/blocks.dart';
import 'doc_nodes.dart';

/// Where a document tree came from: the Markdown it was read from, and the
/// nodes as read, whose lines a printer copies while they stay.
final class Origin {
  Origin(this.markdown, Iterable<DocBlock> loaded)
    : _loaded = Set.identity()..addAll(loaded);

  final DocumentTree markdown;
  final Set<DocBlock> _loaded;

  /// Whether [node] is a node as read: the very object, so it holds what
  /// its source lines say.
  bool isLoaded(DocBlock node) => _loaded.contains(node);

  /// This origin with [nodes] taken as read too: they hold what their
  /// source lines say.
  Origin withLoaded(Iterable<DocBlock> nodes) =>
      Origin(markdown, [..._loaded, ...nodes]);

  /// The Markdown block [block] and the containers it is in, the root
  /// first; `null` for a block of other Markdown.
  PlacedBlock? placeOf(Block block) => switch (markdown.placeOf(block.id)) {
    final placed? when identical(placed.block, block) => placed,
    _ => null,
  };

  late final Map<Block, int> _indexes = () {
    final indexes = Map<Block, int>.identity();
    void walk(Block block) {
      if (block is ContainerBlock) {
        for (final (index, child) in block.children.indexed) {
          indexes[child] = index;
          walk(child);
        }
      }
    }

    walk(markdown.root);
    return indexes;
  }();

  /// Whether [after] is the block right after [before] in the same
  /// Markdown container.
  bool areNeighbors(Block before, Block after) {
    final (first, second) = (placeOf(before), placeOf(after));
    if (first == null || second == null) return false;
    return identical(first.path.last, second.path.last) &&
        _indexes[after] == _indexes[before]! + 1;
  }
}
