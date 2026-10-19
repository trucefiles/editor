import 'block.dart';
import 'line_id.dart';
import 'markdown_lines.dart';

/// What one editor transaction did to the lines it shows.
sealed class BlockEdit {
  const BlockEdit();
}

/// Line [id] now shows [block].
final class BlockChanged extends BlockEdit {
  const BlockChanged(this.id, this.block);

  final LineId id;
  final Block block;
}

/// Line [id] was deleted.
final class BlockRemoved extends BlockEdit {
  const BlockRemoved(this.id);

  final LineId id;
}

/// New [blocks], in order, shown right below line [after]; at the top if
/// `null`.
final class BlocksAdded extends BlockEdit {
  const BlocksAdded(this.blocks, {required this.after});

  final List<Block> blocks;
  final LineId? after;
}

/// The single mapping from editor blocks to file lines.
extension ApplyBlockEdits on MarkdownLines {
  /// Applies [edits]: a changed block changes only its own line, keeping
  /// its prefix style; a removed block removes its line; added blocks go
  /// after the line shown above them (see [MarkdownLines.insertBlocks]).
  /// Every other line stays byte-identical and in place. [shown] are the
  /// lines the editor shows. Returns the ids of the added lines, in the
  /// order of [edits].
  (MarkdownLines, List<LineId>) applyEdits(
    List<BlockEdit> edits, {
    required Set<LineId> shown,
  }) {
    var lines = this;
    final added = <LineId>[];
    for (final edit in edits) {
      switch (edit) {
        case BlockChanged(:final id, :final block):
          lines = lines.withBlock(id, block);
        case BlockRemoved(:final id):
          lines = lines.removeLine(id);
        case BlocksAdded(:final blocks, :final after):
          final (withAdded, ids) = lines.insertBlocks(
            blocks,
            after: after,
            shown: shown,
          );
          lines = withAdded;
          added.addAll(ids);
      }
    }
    return (lines, added);
  }
}
