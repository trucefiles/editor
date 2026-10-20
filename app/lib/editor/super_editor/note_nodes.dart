import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'display_nodes.dart';

/// The node [id] showing a line as its [view] says, with [text]: a task or
/// list item at its level, numbered as the file says (see
/// [listNumberKey]); else a paragraph, a quote if it shows as one, or of
/// [blockType] if given.
DocumentNode lineNode(
  String id,
  LineView view,
  AttributedText text, {
  Attribution? blockType,
}) => switch (view.item) {
  (kind: ListKind.checkbox, :final depth, :final checked, number: _) =>
    TaskNode(id: id, text: text, isComplete: checked, indent: depth),
  (kind: ListKind.bullet, :final depth, checked: _, number: _) =>
    ListItemNode.unordered(id: id, text: text, indent: depth),
  (kind: ListKind.numbered, :final depth, checked: _, :final number) =>
    ListItemNode.ordered(
      id: id,
      text: text,
      indent: depth,
      metadata: {listNumberKey: number},
    ),
  null => ParagraphNode(
    id: id,
    text: text,
    metadata: switch (blockType ??
        (view.quote ? blockquoteAttribution : null)) {
      final type? => {NodeMetadata.blockType: type},
      null => null,
    },
  ),
};

/// Whether [node], made by [lineNode], shows an item's text after its
/// marker, not its whole line.
bool showsItemText(DocumentNode node) =>
    node is ListItemNode || node is TaskNode;

/// The node of [entry], which is no line, whose lines [byId] holds.
DisplayNode displayNode(DisplayEntry entry, Map<LineId, MarkdownLine> byId) =>
    switch (entry) {
      DoneHeadingEntry() => DoneHeadingNode(entry),
      AddItemEntry() => AddItemNode(entry),
      TableEntry(:final ids) => DrawnTableNode([
        for (final id in ids) byId[id]!,
      ]),
      ImageEntry(:final id) => DrawnImageNode(byId[id]!, entry),
      LineEntry() => throw ArgumentError.value(entry, 'entry', 'is a line'),
    };

/// The metadata key of the number a numbered item shows, as its file
/// says (see [MarkdownLines.numberOf]).
const listNumberKey = 'listNumber';

/// What the editor shows in [node], if it is a line.
Block? blockOf(DocumentNode node) => switch (node) {
  TaskNode(:final isComplete, :final indent, :final text) => ItemBlock(
    kind: ListKind.checkbox,
    checked: isComplete,
    depth: indent,
    text: text.toPlainText(),
  ),
  ListItemNode(:final type, :final indent, :final text) => ItemBlock(
    kind: type == ListItemType.ordered ? ListKind.numbered : ListKind.bullet,
    depth: indent,
    text: text.toPlainText(),
  ),
  TextNode(:final text) => TextBlock(text.toPlainText()),
  _ => null,
};
