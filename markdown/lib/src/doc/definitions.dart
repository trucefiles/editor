import '../read/document_reading.dart';
import '../read/syntax/link_syntax.dart';
import '../tree/blocks.dart';
import 'doc_nodes.dart';

/// The link reference definitions [root] holds, by normalized label; the
/// first of a label counts.
Map<String, LinkDefinition> definitionsOf(DocRoot root) => definitionsByLabel(
  nodesIn(root)
      .whereType<RawNode>()
      .where((node) => node.kind == RawKind.definitions)
      .expand((node) => _definitionsIn(node.raw)),
);

/// The definitions [raw] starts with, one after another.
Iterable<LinkDefinition> _definitionsIn(String raw) sync* {
  for (
    var read = readLinkDefinition(raw, 0);
    read != null && read.end > 0;
    read = readLinkDefinition(raw, read.end)
  ) {
    yield read.value;
  }
}
