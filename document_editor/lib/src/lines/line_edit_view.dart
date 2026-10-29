import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../document_metrics.dart';
import '../library/editor_look.dart';
import '../library/link_tap_handler.dart';
import '../library/own_paste.dart';
import '../library/touch_controls.dart';
import '../ui/empty_document_hint.dart';
import 'edited_text.dart';
import 'library/line_keys.dart';
import 'library/lines_adapter.dart';
import 'line_highlighter.dart';

/// How a line editor draws its lines: each as [look] says, styled
/// further by the [highlighter] made for it (e.g. Markdown's highlights),
/// if any.
final class LineEditing {
  const LineEditing({required this.look, this.highlighter});

  final EditorLook Function(ThemeData theme, DocumentMetrics metrics) look;
  final LineHighlighter Function(LinesAdapter adapter)? highlighter;
}

/// A text edited line by line as it is written: Markdown edit, or a plain
/// text. Links, where its highlighter finds them, open with [onLink]
/// on a tap with Ctrl (or Cmd) held, so a plain tap places the caret.
class LineEditView extends StatefulWidget {
  const LineEditView(
    this.text, {
    required this.editing,
    this.onLink = _ignore,
    this.autofocus = false,
    super.key,
  });

  final EditedText text;
  final LineEditing editing;
  final void Function(String url) onLink;

  static void _ignore(String _) {}

  /// Puts the caret into the document right away, e.g. a new one.
  final bool autofocus;

  @override
  State<LineEditView> createState() => _LineEditViewState();
}

class _LineEditViewState extends State<LineEditView> {
  late final LinesAdapter _adapter;
  late final LineHighlighter? _highlighter;
  late final List<SingleColumnLayoutStylePhase> _phases;
  final _layout = GlobalKey();
  late final _operations = PasteOperations(
    _adapter.editor,
    _adapter.paste,
    layout: _layout,
  );

  /// The look in the current theme and metrics. Kept between builds:
  /// the library lays the whole document out anew for each new
  /// stylesheet.
  EditorLook? _look;
  (ThemeData, DocumentMetrics)? _lookFor;

  @override
  void initState() {
    super.initState();
    _adapter = LinesAdapter(widget.text);
    _highlighter = widget.editing.highlighter?.call(_adapter);
    _phases = [?_highlighter?.phase];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = (Theme.of(context), DocumentMetrics.of(context));
    if (key == _lookFor) return;
    _lookFor = key;
    _look = widget.editing.look(key.$1, key.$2);
  }

  @override
  void dispose() {
    _highlighter?.dispose();
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
          operations: _operations,
          child: SuperEditor(
            editor: _adapter.editor,
            documentLayoutKey: _layout,
            autofocus: widget.autofocus,
            stylesheet: look.stylesheet,
            selectionStyle: look.selection,
            documentOverlayBuilders: look.overlays,
            customStylePhases: _phases,
            keyboardActions: lineKeyboardActions(_adapter.paste),
            contentTapDelegateFactories: [
              if (_highlighter case final highlighter?)
                (_) => LinkTapHandler(
                  linkAt: highlighter.linkAt,
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
          listenable: _adapter.linesChanged,
          builder: (context, _) => EmptyDocumentHint(
            empty: _adapter.text.isEmpty,
            padding: look.firstLinePadding,
          ),
        ),
      ],
    );
  }
}
