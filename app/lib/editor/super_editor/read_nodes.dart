import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'display_nodes.dart';
import 'edit_nodes.dart';
import 'marks/markup_text.dart';
import 'note_look.dart';

/// The nodes for [entries] of [document] to read: each line formatted,
/// its Markdown syntax hidden; list items as in Visual edit; "Done" headings
/// and drawn tables and images as in Visual edit. A run of blank lines
/// shows as one small gap, as between paragraphs.
List<DocumentNode> readNodes(
  List<DisplayEntry> entries,
  MarkdownLines document,
) {
  final byId = {for (final line in document.lines) line.id: line};
  bool blank(DisplayEntry? entry) =>
      entry is LineEntry &&
      entry.kind == LineKind.plain &&
      byId[entry.id]!.raw.trim().isEmpty;
  return [
    for (final (index, entry) in entries.indexed)
      if (blank(entry) && index > 0 && blank(entries[index - 1]))
        ...const <DocumentNode>[]
      else if (blank(entry))
        ParagraphNode(
          id: 'line-${(entry as LineEntry).id}',
          text: AttributedText(),
          metadata: const {NodeMetadata.blockType: gapBlock},
        )
      else
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
  if (document.isItem(line)) {
    return itemNode(
      id,
      line,
      _formatted(line.text, itemTextMarkup(line.text)),
      document,
    );
  }
  final quote = document.isQuote(line);
  return lineParagraph(
    id,
    _formatted(line.raw, lineMarkup(line.raw, kind, inQuote: quote)),
    quote: quote,
  );
}

AttributedText _formatted(String source, List<MarkupSpan> markup) {
  final visual = VisualLine.of(source, markup);
  return markupText(visual.text, visual.markup);
}
