import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart' show EditableLines;

import '../document_metrics.dart';
import '../library/editor_look.dart';
import '../library/link_tap_handler.dart';
import '../library/own_paste.dart';
import '../library/touch_controls.dart';
import '../ui/empty_document_hint.dart';
import 'edited_text.dart';
import 'library/line_keys.dart';
import 'library/lines_adapter.dart';

/// How a line editor reads its lines and draws them: the lines read as
/// [read] reads them, each drawn as [look] says, styled further by the
/// [phases] (e.g. highlights); [linkAt] finds the link at a position, if
/// links open at all.
final class LineEditing<L extends EditableLines<L>> {
  const LineEditing({
    required this.read,
    required this.look,
    this.phases,
    this.linkAt,
  });

  final L Function(String text) read;
  final EditorLook Function(ThemeData theme, DocumentMetrics metrics) look;
  final List<SingleColumnLayoutStylePhase> Function(LinesAdapter<L> adapter)?
  phases;
  final String? Function(LinesAdapter<L> adapter, DocumentPosition position)?
  linkAt;
}

/// A text edited line by line as it is written: Markdown edit, or a plain
/// text. Links, where [LineEditing.linkAt] finds them, open with [onLink]
/// on a tap with Ctrl (or Cmd) held, so a plain tap places the caret.
class LineEditView<L extends EditableLines<L>> extends StatefulWidget {
  const LineEditView(
    this.text, {
    required this.editing,
    this.onLink = _ignore,
    this.autofocus = false,
    super.key,
  });

  final EditedText text;
  final LineEditing<L> editing;
  final void Function(String url) onLink;

  static void _ignore(String _) {}

  /// Puts the caret into the document right away, e.g. a new one.
  final bool autofocus;

  @override
  State<LineEditView<L>> createState() => _LineEditViewState<L>();
}

class _LineEditViewState<L extends EditableLines<L>>
    extends State<LineEditView<L>> {
  late final _adapter = LinesAdapter<L>(widget.text, read: widget.editing.read);
  late final _phases = widget.editing.phases?.call(_adapter) ?? const [];
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final key = (Theme.of(context), DocumentMetrics.of(context));
    if (key == _lookFor) return;
    _lookFor = key;
    _look = widget.editing.look(key.$1, key.$2);
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
              if (widget.editing.linkAt case final linkAt?)
                (_) => LinkTapHandler(
                  linkAt: (position) => linkAt(_adapter, position),
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
