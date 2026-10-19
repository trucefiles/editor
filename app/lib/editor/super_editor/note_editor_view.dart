import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../../notes/note_mode.dart';
import '../note_document_controller.dart';
import '../text_format.dart';
import '../ui/format_toolbar.dart';
import '../ui/link_dialog.dart';
import 'apply_format.dart';
import 'components/display_component_builder.dart';
import 'components/list_line_builder.dart';
import 'link_tap_handler.dart';
import 'marks/mapped_builder.dart';
import 'marks/marks_phase.dart';
import 'marks/visual_lines.dart';
import 'note_editor_adapter.dart';
import 'note_keyboard_actions.dart';
import 'note_read_document.dart';
import 'note_stylesheet.dart';

/// The open [note] in its mode: editable in Visual and Markdown edit, with
/// the format toolbar in Visual edit; read-only in Read, where links open
/// with [onLink]. Built anew for each mode.
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
      visual: _mode == NoteMode.visual ? _visualLines : null,
      composer: adapter.editor.composer,
    );
    if (widget.autofocus) adapter.placeCaretAtStart();
  }

  @override
  void dispose() {
    _adapter?.dispose();
    _read?.dispose();
    _marks?.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _format(TextFormat format) async {
    final editor = _adapter!.editor;
    var url = '';
    if (format == TextFormat.link) {
      url = await askLinkUrl(context) ?? '';
      if (url.isEmpty) return;
    }
    applyFormat(editor, format, url: url);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stylesheet = noteStylesheet(
      theme,
      monospace: _mode == NoteMode.markdown,
    );
    if (_read case final read?) {
      return SuperReader(
        editor: read.editor,
        stylesheet: stylesheet,
        selectionStyle: noteSelectionStyles(theme),
        componentBuilders: const [
          ListLineBuilder(),
          DisplayComponentBuilder(),
          ParagraphComponentBuilder(),
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
      stylesheet: stylesheet,
      selectionStyle: noteSelectionStyles(theme),
      customStylePhases: [_marks!],
      componentBuilders: visual
          ? _visualBuilders(adapter)
          : const [ParagraphComponentBuilder()],
      keyboardActions: noteKeyboardActions(
        onFormat: _format,
        lineActions: visual ? adapter : null,
      ),
      contentTapDelegateFactories: const [],
    );
    if (!visual) return editor;
    return Column(
      children: [
        Expanded(child: editor),
        FormatToolbar(onFormat: _format, onStartList: adapter.startList),
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
        const ParagraphComponentBuilder(),
        _visualLines,
      ),
    ];
  }
}
