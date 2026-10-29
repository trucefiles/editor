import 'package:collection/collection.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

import '../../lines/library/lines_adapter.dart';
import '../../lines/line_edit_view.dart';
import '../ui/markdown_look.dart';
import 'highlight_phase.dart';

/// Markdown edit's lines: read as Markdown, highlighted as they read.
final markdownLines = LineEditing<md.DocumentTree>(
  read: md.DocumentTree.read,
  look: (theme, metrics) => markdownLook(theme, metrics: metrics),
  phases: (adapter) => [
    HighlightPhase((nodeId) => lineHighlightsOf(adapter, nodeId)),
  ],
  linkAt: lineLinkAt,
);

/// The highlights of the line node [nodeId] shows; none for one the
/// library just made.
List<md.HighlightSpan> lineHighlightsOf(
  LinesAdapter<md.DocumentTree> adapter,
  String nodeId,
) => switch (adapter.lineOf(nodeId)) {
  final line? => md.highlightsOf(adapter.tree, line),
  null => const [],
};

/// Where the link at [position] leads, if its text is part of one.
String? lineLinkAt(
  LinesAdapter<md.DocumentTree> adapter,
  DocumentPosition position,
) => switch (position.nodePosition) {
  TextNodePosition(:final offset) =>
    lineHighlightsOf(adapter, position.nodeId)
        .where((span) => span.start <= offset && offset < span.end)
        .map((span) => span.highlight)
        .whereType<md.LinkHighlight>()
        .lastOrNull
        ?.destination,
  _ => null,
};
