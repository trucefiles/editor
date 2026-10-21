import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../note_document_controller.dart';
import '../note_mode.dart';
import '../text_format.dart';
import '../ui/empty_note_hint.dart';
import '../ui/format_toolbar.dart';
import '../ui/link_dialog.dart';
import '../ui/note_image.dart';
import '../ui/note_read_view.dart';
import 'apply_format.dart';
import 'components/display_component_builder.dart';
import 'components/leaf_builder.dart';
import 'link_tap_handler.dart';
import 'marks/mapped_builder.dart';
import 'marks/marks_phase.dart';
import 'marks/shown_texts.dart';
import 'note_editor_adapter.dart';
import 'note_keyboard_actions.dart';
import 'note_look.dart';

/// The open [note] in its mode: editable in Visual and Markdown edit, with
/// the format toolbar in Visual edit; read-only in Read. Links open with
/// [onLink] (see [editingTapOpens] while editing); images show as
/// [images] finds them. Built anew for each mode.
class NoteEditorView extends StatefulWidget {
  const NoteEditorView(
    this.note, {
    required this.onRemoved,
    required this.onLink,
    required this.images,
    this.autofocus = false,
    super.key,
  });

  final NoteDocumentController note;

  /// The user removed items; [undo] brings them back.
  final void Function(String message, EditUndo undo) onRemoved;
  final void Function(String url) onLink;
  final NoteImages images;

  /// Puts the caret into the note right away, e.g. a new one.
  final bool autofocus;

  @override
  State<NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<NoteEditorView> {
  late final NoteMode _mode = widget.note.mode;
  final _focus = FocusNode();
  final _shownTexts = ShownTexts();
  NoteEditorAdapter? _adapter;
  MarksPhase? _marks;

  /// The look in the current theme. Kept between builds: super_editor
  /// lays the whole note out anew for each new stylesheet.
  late NoteLook _look;

  @override
  void initState() {
    super.initState();
    if (!_mode.edits) return;
    final adapter = NoteEditorAdapter(
      widget.note,
      onRemoved: (message, undo) => widget.onRemoved(message, undo),
      onCaretPlaced: _focus.requestFocus,
    );
    _adapter = adapter;
    _marks = MarksPhase(
      marks: _mode.marks,
      viewOf: adapter.viewOf,
      texts: _shownTexts,
      composer: adapter.editor.composer,
    );
    if (widget.autofocus) adapter.placeCaretAtStart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    if (theme != _lookTheme) {
      _lookTheme = theme;
      _look = NoteLook(
        theme,
        monospace: _mode == NoteMode.markdown,
        images: widget.images,
      );
    }
  }

  ThemeData? _lookTheme;

  @override
  void dispose() {
    _adapter?.dispose();
    _marks?.close();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _format(TextFormat format) async {
    final editor = _adapter!.editor;
    // Taken before the link dialog: the editor drops its selection once
    // the dialog takes focus.
    final selection = editor.composer.selection;
    var url = '';
    if (format == TextFormat.link) {
      final before = _textOf(selection);
      url = await askLinkUrl(context) ?? '';
      // Changed from elsewhere meanwhile: the selection may no longer fit.
      if (url.isEmpty || _textOf(selection) != before) return;
    }
    applyFormat(
      editor,
      format,
      selection: selection,
      viewOf: _adapter!.viewOf,
      url: url,
    );
    _focus.requestFocus();
  }

  /// The text of the node [selection] ends in, if any.
  String? _textOf(DocumentSelection? selection) => switch (selection) {
    final selection? => switch (_adapter!.editor.document.getNodeById(
      selection.extent.nodeId,
    )) {
      final TextNode node => node.text.toPlainText(),
      _ => null,
    },
    null => null,
  };

  void _toList(ListKind kind) {
    _adapter!.toList(kind);
    _focus.requestFocus();
  }

  void _lineBreak() {
    _adapter!.lineBreak();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final adapter = _adapter;
    if (adapter == null) {
      return NoteReadView(
        widget.note,
        onLink: widget.onLink,
        images: widget.images,
      );
    }
    final look = _look;
    final visual = _mode == NoteMode.visual;
    final editor = SuperEditor(
      editor: adapter.editor,
      focusNode: _focus,
      autofocus: widget.autofocus,
      stylesheet: look.stylesheet,
      selectionStyle: look.selection,
      documentOverlayBuilders: look.overlays,
      androidHandleColor: look.handleColor,
      customStylePhases: [_marks!],
      componentBuilders: [
        MappedBuilder<LeafViewModel>(
          LeafBuilder(actions: visual ? adapter : null),
          _shownTexts,
        ),
        DisplayComponentBuilder(actions: adapter),
      ],
      keyboardActions: noteKeyboardActions(onFormat: _format, keys: adapter),
      contentTapDelegateFactories: [
        (_) => LinkTapHandler(
          linkAt: adapter.linkAt,
          onLink: widget.onLink,
          opens: (position) => editingTapOpens(
            position,
            tapOpens: visual,
            caretNode: adapter.editor.composer.selection?.extent.nodeId,
          ),
        ),
      ],
    );
    final hinted = Stack(
      children: [
        editor,
        EmptyNoteHint(widget.note, padding: noteFirstLinePadding),
      ],
    );
    if (!visual) return hinted;
    return Column(
      children: [
        Expanded(child: hinted),
        FormatToolbar(
          onFormat: _format,
          onList: _toList,
          onLineBreak: _lineBreak,
        ),
      ],
    );
  }
}
