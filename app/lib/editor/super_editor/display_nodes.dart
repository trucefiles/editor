import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

/// A node that is not one editable line: a "Done" heading, an add button,
/// or a drawn table or image. Equal to another with the same id and
/// [content].
sealed class DisplayNode extends BlockNode {
  DisplayNode(this.id, {required bool deletable, super.metadata}) {
    initAddToMetadata({NodeMetadata.isDeletable: deletable});
  }

  @override
  final String id;

  /// Everything this node shows, as one value.
  String get content;

  DisplayNode _copy(Map<String, dynamic> metadata);

  /// The text copied with a selection that covers this node.
  String? get copyText => null;

  @override
  String? copyContent(NodeSelection selection) =>
      selection is UpstreamDownstreamNodeSelection && !selection.isCollapsed
      ? copyText
      : null;

  @override
  bool hasEquivalentContent(DocumentNode other) =>
      other is DisplayNode &&
      other.runtimeType == runtimeType &&
      other.content == content;

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) =>
      _copy({...metadata, ...newProperties});

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) =>
      _copy(newMetadata);

  @override
  bool operator ==(Object other) =>
      other is DisplayNode &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      other.content == content;

  @override
  int get hashCode => Object.hash(id, content);
}

/// The heading of a checklist's "Done" section; see [DoneHeadingEntry].
final class DoneHeadingNode extends DisplayNode {
  DoneHeadingNode(this.entry, {super.metadata})
    : super('done-${entry.list}', deletable: false);

  final DoneHeadingEntry entry;

  @override
  String get content => '${entry.count} ${entry.collapsed}';

  @override
  DisplayNode _copy(Map<String, dynamic> metadata) =>
      DoneHeadingNode(entry, metadata: metadata);
}

/// A checklist's add button; see [AddItemEntry].
final class AddItemNode extends DisplayNode {
  AddItemNode(this.entry, {super.metadata})
    : super('add-${entry.list}', deletable: false);

  final AddItemEntry entry;

  @override
  String get content => '${entry.anchor} ${entry.before}';

  @override
  DisplayNode _copy(Map<String, dynamic> metadata) =>
      AddItemNode(entry, metadata: metadata);
}

/// A table drawn from its lines; see [TableEntry].
final class DrawnTableNode extends DisplayNode {
  DrawnTableNode(this.lines, {super.metadata})
    : rows = tableCells([for (final line in lines) line.raw]),
      super('table-${lines.first.id}', deletable: true);

  /// Its lines: header, delimiter row and rows.
  final List<MarkdownLine> lines;

  /// The header's cells, then each row's.
  final List<List<String>> rows;

  @override
  String get content => copyText;

  @override
  String get copyText => [for (final line in lines) line.raw].join('\n');

  @override
  DisplayNode _copy(Map<String, dynamic> metadata) =>
      DrawnTableNode(lines, metadata: metadata);
}

/// An image drawn from its line; see [ImageEntry].
final class DrawnImageNode extends DisplayNode {
  DrawnImageNode(this.line, this.entry, {super.metadata})
    : super('image-${line.id}', deletable: true);

  final MarkdownLine line;
  final ImageEntry entry;

  @override
  String get content => line.raw;

  @override
  String get copyText => line.raw;

  @override
  DisplayNode _copy(Map<String, dynamic> metadata) =>
      DrawnImageNode(line, entry, metadata: metadata);
}
