import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../editor_gate.dart';
import '../library/editor_look.dart';
import '../library/link_tap_handler.dart';
import '../library/touch_controls.dart';
import '../note_metrics.dart';
import '../ui/empty_note_hint.dart';
import 'library/highlight_phase.dart';
import 'library/markdown_adapter.dart';
import 'library/markdown_keys.dart';
import 'ui/markdown_look.dart';

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
  late final _adapter = MarkdownAdapter(widget.gate);
  late final _highlights = HighlightPhase(_adapter.highlightsOf);

  /// The look in the current theme and metrics. Kept between builds:
  /// the library lays the whole document out anew for each new
  /// stylesheet.
  EditorLook? _look;
  (ThemeData, NoteMetrics)? _lookFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = (Theme.of(context), NoteMetrics.of(context));
    if (key == _lookFor) return;
    _lookFor = key;
    _look = markdownLook(key.$1, metrics: key.$2);
  }

  @override
  void dispose() {
    _adapter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = _look!;
    return Stack(
      children: [
        TouchControls(
          color: look.handleColor,
          child: SuperEditor(
            editor: _adapter.editor,
            autofocus: widget.autofocus,
            stylesheet: look.stylesheet,
            selectionStyle: look.selection,
            documentOverlayBuilders: look.overlays,
            customStylePhases: [_highlights],
            keyboardActions: markdownKeyboardActions(),
            contentTapDelegateFactories: [
              (_) => LinkTapHandler(
                linkAt: _adapter.linkAt,
                onLink: widget.onLink,
                opens: (position) => editingTapOpens(
                  position,
                  tapOpens: false,
                  caretNode: _adapter.composer.selection?.extent.nodeId,
                ),
              ),
            ],
          ),
        ),
        ListenableBuilder(
          listenable: _adapter.treeChanged,
          builder: (context, _) => EmptyNoteHint(
            empty: _adapter.tree.text.isEmpty,
            padding: look.firstLinePadding,
          ),
        ),
      ],
    );
  }
}
