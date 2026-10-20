import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../note_mode.dart';
import 'line_nodes.dart';
import 'marks/markup_text.dart';
import 'note_look.dart';
import 'note_nodes.dart';

/// The nodes for [entries] of [document] to read in [mode]: each line as
/// its marks and blocks show there, with "Done" headings and drawn tables
/// and images. A run of blank lines shows as one small gap, as between
/// paragraphs.
List<DocumentNode> readNodes(
  List<DisplayEntry> entries,
  MarkdownLines document, {
  required NoteMode mode,
}) {
  final byId = {for (final line in document.lines) line.id: line};
  bool blank(DisplayEntry? entry) =>
      entry is LineEntry &&
      entry.kind == LineKind.plain &&
      byId[entry.id]!.isBlank;
  return [
    for (final (index, entry) in entries.indexed)
      if (!(blank(entry) && index > 0 && blank(entries[index - 1])))
        switch (entry) {
          LineEntry(:final id) => _lineNode(
            LineView.of(document, byId[id]!, blocks: mode.showsBlocks),
            mode.marks,
            gap: blank(entry),
          ),
          _ => displayNode(entry, byId),
        },
  ];
}

DocumentNode _lineNode(LineView view, MarkStyle marks, {required bool gap}) {
  final shown = marks.show(view.text, view.markupOf(view.text), edited: false);
  return lineNode(
    LineNodes.idFor(view.id),
    view,
    gap ? AttributedText() : markupText(shown.text, shown.markup),
    blockType: gap ? gapBlock : null,
  );
}
