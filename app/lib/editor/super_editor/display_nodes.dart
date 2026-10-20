import 'package:collection/collection.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

/// A node that is not text the user types in: a "Done" heading, an add
/// button, or a drawn table. Equal to another with the same id and
/// [content].
sealed class DisplayNode extends BlockNode {
  DisplayNode(this.id, {required bool deletable, super.metadata}) {
    initAddToMetadata({NodeMetadata.isDeletable: deletable});
  }

  @override
  final String id;

  /// Everything this node shows.
  List<Object?> get content;

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
      _equality.equals(other.content, content);

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) =>
      _copy({...metadata, ...newProperties});

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) =>
      _copy(newMetadata);

  @override
  bool operator ==(Object other) =>
      other is DisplayNode && other.id == id && hasEquivalentContent(other);

  @override
  int get hashCode => Object.hash(id, _equality.hash(content));

  static const _equality = ListEquality<Object?>();
}

/// The heading of a list's "Done" section; see [DoneHeadingEntry].
final class DoneHeadingNode extends DisplayNode {
  DoneHeadingNode(super.id, this.entry, {super.metadata})
    : super(deletable: false);

  final DoneHeadingEntry entry;

  @override
  List<Object?> get content => [entry.count, entry.collapsed];

  @override
  DisplayNode _copy(Map<String, dynamic> metadata) =>
      DoneHeadingNode(id, entry, metadata: metadata);
}

/// A list's add button; see [AddItemEntry].
final class AddItemNode extends DisplayNode {
  AddItemNode(super.id, this.entry, {super.metadata}) : super(deletable: false);

  final AddItemEntry entry;

  @override
  List<Object?> get content => [entry.anchor, entry.before];

  @override
  DisplayNode _copy(Map<String, dynamic> metadata) =>
      AddItemNode(id, entry, metadata: metadata);
}

/// A table drawn as a grid, inside [frames]; see [TableEntry].
final class DrawnTableNode extends DisplayNode {
  DrawnTableNode(super.id, this.table, {required this.frames, super.metadata})
    : super(deletable: true);

  final TableBlock table;
  final List<Frame> frames;

  @override
  List<Object?> get content => [table.text, ...frames];

  @override
  String get copyText => table.text;

  @override
  DisplayNode _copy(Map<String, dynamic> metadata) =>
      DrawnTableNode(id, table, frames: frames, metadata: metadata);
}
