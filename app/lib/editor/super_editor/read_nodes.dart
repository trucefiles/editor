import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'display_nodes.dart';
import 'marks/markup_text.dart';

/// The nodes for [entries] of [document] to read: each line formatted,
/// its Markdown syntax hidden; checkbox items as tasks; "Done" headings
/// and drawn tables and images as in Visual edit.
List<DocumentNode> readNodes(
  List<DisplayEntry> entries,
  MarkdownLines document,
) {
  final byId = {for (final line in document.lines) line.id: line};
  return [
    for (final entry in entries)
      switch (entry) {
        LineEntry(:final id, :final kind) => _lineNode(
          byId[id]!,
          kind,
          document,
        ),
        DoneHeadingEntry() => DoneHeadingNode(entry),
        AddItemEntry() => AddItemNode(entry),
        TableEntry(:final ids) => DrawnTableNode([
          for (final id in ids) byId[id]!,
        ]),
        ImageEntry(:final id) => DrawnImageNode(byId[id]!, entry),
      },
  ];
}

DocumentNode _lineNode(
  MarkdownLine line,
  LineKind kind,
  MarkdownLines document,
) {
  final id = 'line-${line.id}';
  if (kind == LineKind.plain && line.isItem) {
    return TaskNode(
      id: id,
      text: _formatted(line.text, itemTextMarkup(line.text)),
      isComplete: line.isChecked,
      indent: document.depthOf(line),
    );
  }
  return ParagraphNode(
    id: id,
    text: _formatted(line.raw, lineMarkup(line.raw, kind)),
  );
}

AttributedText _formatted(String source, List<MarkupSpan> markup) {
  final visual = VisualLine.of(source, markup);
  return markupText(visual.text, visual.markup);
}
