import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../note_document_controller.dart';
import '../note_mode.dart';
import '../text_format.dart';
import '../ui/empty_note_hint.dart';
import '../ui/format_toolbar.dart';
import '../ui/link_dialog.dart';
import 'apply_format.dart';
import 'components/display_component_builder.dart';
import 'components/list_line_builder.dart';
import 'components/quote_line_builder.dart';
import 'editor_link_tap_handler.dart';
import 'link_tap_handler.dart';
import 'marks/mapped_builder.dart';
import 'marks/marks_phase.dart';
import 'marks/visual_lines.dart';
import 'note_editor_adapter.dart';
import 'note_keyboard_actions.dart';
import 'note_look.dart';
import 'note_read_document.dart';

/// The open [note] in its mode: editable in Visual and Markdown edit, with
/// the format toolbar in Visual edit; read-only in Read. Links open with
/// [onLink] (see [EditorLinkTapHandler] while editing). Built anew for
/// each mode.
class NoteEditorView extends StatefulWidget {
  const NoteEditorView(
    this.note, {
    required this.onRemoved,
    required this.onLink,
    this.autofocus = false,
    super.key,
  });

  final NoteDocumentController note;

  /// The user removed items; [undo] brings them back.
  final void Function(String message, EditUndo undo) onRemoved;
  final void Function(String url) onLink;

  /// Puts the caret into the note right away, e.g. a new one.
  final bool autofocus;

  @override
  State<NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<NoteEditorView> {
  late final NoteMode _mode = widget.note.mode;
  final _focus = FocusNode();
  final _visualLines = VisualLines();
  NoteEditorAdapter? _adapter;
  NoteReadDocument? _read;
  MarksPhase? _marks;

  /// The look in the current theme. Kept between builds: super_editor
  /// lays the whole note out anew for each new stylesheet.
  late NoteLook _look;

  @override
  void initState() {
    super.initState();
    if (!_mode.edits) {
      _read = NoteReadDocument(widget.note);
      return;
    }
    final adapter = NoteEditorAdapter(
      widget.note,
      onRemoved: (message, undo) => widget.onRemoved(message, undo),
      onCaretPlaced: _focus.requestFocus,
    );
    _adapter = adapter;
    _marks = MarksPhase(
      kindOf: adapter.kindOf,
      visual: _mode == NoteMode.visual ? _visualLines : null,
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
      _look = NoteLook(theme, monospace: _mode == NoteMode.markdown);
    }
  }

  ThemeData? _lookTheme;

  @override
  void dispose() {
    _adapter?.dispose();
    _read?.dispose();
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
      url = await askLinkUrl(context) ?? '';
      if (url.isEmpty) return;
    }
    applyFormat(
      editor,
      format,
      selection: selection,
      kindOf: _adapter!.kindOf,
      url: url,
    );
    _focus.requestFocus();
  }

  void _toList(ListKind kind) {
    _adapter!.toList(kind);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final look = _look;
    if (_read case final read?) {
      return SuperReader(
        editor: read.editor,
        stylesheet: look.stylesheet,
        selectionStyle: look.selection,
        componentBuilders: const [
          ListLineBuilder(),
          DisplayComponentBuilder(),
          QuoteLineBuilder(),
        ],
        contentTapDelegateFactory: (context) =>
            LinkTapHandler(context.document, onLink: widget.onLink),
      );
    }
    final adapter = _adapter!;
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
      componentBuilders: visual
          ? _visualBuilders(adapter)
          : const [ParagraphComponentBuilder()],
      keyboardActions: noteKeyboardActions(
        onFormat: _format,
        lineActions: visual ? adapter : null,
      ),
      contentTapDelegateFactories: [
        (_) => EditorLinkTapHandler(
          adapter.editor,
          kindOf: adapter.kindOf,
          tapOpens: visual,
          onLink: widget.onLink,
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
        FormatToolbar(onFormat: _format, onList: _toList),
      ],
    );
  }

  List<ComponentBuilder> _visualBuilders(NoteEditorAdapter adapter) {
    final lines = ListLineBuilder(editor: adapter.editor, actions: adapter);
    return [
      MappedBuilder<TaskComponentViewModel>(lines, _visualLines),
      MappedBuilder<ListItemComponentViewModel>(lines, _visualLines),
      DisplayComponentBuilder(actions: adapter),
      MappedBuilder<ParagraphComponentViewModel>(
        const QuoteLineBuilder(),
        _visualLines,
      ),
    ];
  }
}
