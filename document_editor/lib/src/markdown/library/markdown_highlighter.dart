import 'dart:async';

import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart' show StartTimer;
import 'package:truce_markdown/truce_markdown.dart' as md;

import '../../lines/library/lines_adapter.dart';
import '../../lines/line_edit_view.dart';
import '../../lines/line_highlighter.dart';
import '../ui/markdown_look.dart';
import 'highlight_phase.dart';

/// Markdown edit's lines: highlighted as they read.
final markdownLines = LineEditing(
  look: (theme, metrics) => markdownLook(theme, metrics: metrics),
  highlighter: MarkdownHighlighter.new,
);

/// Highlights a line editor's lines as Markdown reads them: reads the
/// whole text at once, again at once after a text from elsewhere, and
/// after the user's edits once the lines have not changed for [pause], so
/// a read never runs while the user types. Meanwhile each line keeps the
/// highlights it had, cut to its text; a new line has none. Links are
/// found only on lines that are as read. [startTimer] stands in for
/// [Timer.new].
final class MarkdownHighlighter implements LineHighlighter {
  MarkdownHighlighter(
    this._adapter, {
    this.pause = const Duration(seconds: 1),
    this.startTimer = Timer.new,
  }) {
    _read();
    _adapter.linesChanged.addListener(_onLinesChanged);
  }

  final LinesAdapter _adapter;
  final Duration pause;
  final StartTimer startTimer;
  Timer? _timer;

  /// Each line node's text as read, and its highlights.
  var _lines = <String, _ReadLine>{};

  @override
  late final HighlightPhase phase = HighlightPhase(
    (nodeId) => _lines[nodeId]?.highlights ?? const [],
  );

  void _onLinesChanged() {
    _timer?.cancel();
    switch (_adapter.lastChange) {
      case LinesChange.edited:
        _timer = startTimer(pause, _readAgain);
      case LinesChange.replaced:
        _readAgain();
    }
  }

  void _readAgain() {
    _read();
    phase.highlightsChanged();
  }

  /// Reads the lines the nodes show now.
  void _read() {
    final nodes = _adapter.lines;
    final highlights = md.highlightsOf(
      md.DocumentTree.read(nodes.map((node) => node.text).join('\n')),
    );
    _lines = {
      for (final (index, node) in nodes.indexed)
        node.id: (
          text: node.text,
          highlights: highlights.elementAtOrNull(index) ?? const [],
        ),
    };
  }

  @override
  String? linkAt(DocumentPosition position) {
    final read = _lines[position.nodeId];
    if (read == null || _adapter.lineOf(position.nodeId) != read.text) {
      return null;
    }
    return switch (position.nodePosition) {
      TextNodePosition(:final offset) =>
        read.highlights
            .where((span) => span.start <= offset && offset < span.end)
            .map((span) => span.highlight)
            .whereType<md.LinkHighlight>()
            .lastOrNull
            ?.destination,
      _ => null,
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    _adapter.linesChanged.removeListener(_onLinesChanged);
  }
}

/// A line's text as read, and its highlights.
typedef _ReadLine = ({String text, List<md.HighlightSpan> highlights});
