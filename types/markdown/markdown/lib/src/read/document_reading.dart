import '../tree/blocks.dart';
import 'block_freezer.dart';
import 'block_reader.dart';
import 'syntax/characters.dart';

/// A block and the containers it is in, outermost (the root) first.
typedef PlacedBlock = ({Block block, List<ContainerBlock> path});

/// A reading of lines: the [root] read and the link [definitions] by
/// normalized label.
typedef DocumentReading = ({
  RootBlock root,
  Map<String, LinkDefinition> definitions,
});

/// Reads all of [lines], each line's text without its ending.
DocumentReading readDocument(List<String> lines) {
  final root = readOpenBlocks(lines);
  final definitions = definitionsByLabel(definitionsRead(root));
  return (
    root: freezeBlocks(root, lines, definitions: definitions),
    definitions: definitions,
  );
}

/// [definitions] by normalized label; the first of a label counts.
Map<String, LinkDefinition> definitionsByLabel(
  Iterable<LinkDefinition> definitions,
) {
  final byLabel = <String, LinkDefinition>{};
  for (final definition in definitions) {
    byLabel.putIfAbsent(normalizeLabel(definition.label), () => definition);
  }
  return byLabel;
}
