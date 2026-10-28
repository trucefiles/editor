import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

import '../editor_gate.dart';
import '../lines/edited_text.dart';
import '../lines/line_edit_view.dart';
import 'library/markdown_lines.dart';

/// Markdown edit of the document behind [gate]: its text as written,
/// line by line, highlighted as it reads. Links open with [onLink] on a
/// tap with Ctrl (or Cmd) held, so a plain tap places the caret.
class MarkdownEditView extends StatefulWidget {
  const MarkdownEditView(
    this.gate, {
    required this.onLink,
    this.autofocus = false,
    super.key,
  });

  final EditorGate gate;
  final void Function(String url) onLink;

  /// Puts the caret into the document right away, e.g. a new one.
  final bool autofocus;

  @override
  State<MarkdownEditView> createState() => _MarkdownEditViewState();
}

class _MarkdownEditViewState extends State<MarkdownEditView> {
  late final _text = MarkdownText(widget.gate);

  @override
  Widget build(BuildContext context) => LineEditView<md.DocumentTree>(
    _text,
    editing: markdownLines,
    onLink: widget.onLink,
    autofocus: widget.autofocus,
  );
}

/// The text Markdown edit edits: the editor owner's, behind [_gate].
final class MarkdownText implements EditedText {
  MarkdownText(this._gate);

  final EditorGate _gate;

  @override
  ShownText? get shown => switch (_gate.state.content) {
    md.MarkdownContent(:final text, :final caret) => (text: text, caret: caret),
    md.FormattedContent() => null,
  };

  @override
  void edit(String text) =>
      _gate.send((now) => md.EditText(text, revision: now.revision));

  @override
  void addListener(VoidCallback listener) => _gate.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _gate.removeListener(listener);
}
