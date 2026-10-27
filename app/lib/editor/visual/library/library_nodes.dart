import 'package:super_editor/super_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' show textOf;

import '../row_looks.dart';
import 'attributed_text.dart';

/// The metadata key of the look a node shows.
const _lookKey = 'look';

/// The look [node] shows; every node of a Visual edit document has one.
RowLook lookOf(DocumentNode node) => node.getMetadataValue(_lookKey) as RowLook;

/// The library node [id] showing [look]: text the library edits for rows
/// with text, a block for the rest.
DocumentNode libraryNodeOf(String id, RowLook look) => switch (look) {
  TextLook(:final leaf) => ParagraphNode(
    id: id,
    text: attributedTextOf(textOf(leaf)),
    metadata: {_lookKey: look},
  ),
  RawTextLook(:final raw) => ParagraphNode(
    id: id,
    text: AttributedText(raw.text),
    metadata: {_lookKey: look},
  ),
  BlockLook() || DoneHeadingLook() || AddItemLook() => LookBlockNode(id, look),
};

/// A node shown whole, as its [look] says: a divider, table or raw block
/// (removable with the keys), a Done heading or an Add item button (not).
final class LookBlockNode extends BlockNode {
  LookBlockNode(this.id, this.look, {super.metadata}) {
    initAddToMetadata({
      _lookKey: look,
      NodeMetadata.isDeletable: look is BlockLook,
    });
  }

  @override
  final String id;

  final RowLook look;

  @override
  String? copyContent(NodeSelection selection) => null;

  @override
  bool hasEquivalentContent(DocumentNode other) =>
      other is LookBlockNode && other.look == look;

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) =>
      LookBlockNode(id, look, metadata: {...metadata, ...newProperties});

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) =>
      LookBlockNode(id, look, metadata: newMetadata);

  @override
  bool operator ==(Object other) =>
      other is LookBlockNode && other.id == id && other.look == look;

  @override
  int get hashCode => Object.hash(id, look);
}
