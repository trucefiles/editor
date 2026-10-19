import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../../notes/note_mode.dart';
import '../note_document_controller.dart';
import 'components/display_actions.dart';
import 'components/line_actions.dart';
import 'edit_nodes.dart';
import 'join_lines.dart';
import 'line_nodes.dart';
import 'paste_lines.dart';
import 'sync_document.dart';
import 'transaction_edits.dart';

/// Connects a super_editor [editor] to the [note] it edits. The editor
/// only shows the note and takes input: each of its transactions goes to
/// [note] as block edits, which change the file's lines; whenever [note]
/// changes, the editor's document is made to show it again.
final class NoteEditorAdapter implements LineActions, DisplayActions {
  NoteEditorAdapter(
    this.note, {
    required this.onRemoved,
    required this.onCaretPlaced,
  }) {
    _document = MutableDocument(nodes: _targetNodes());
    _composer = MutableDocumentComposer();
    editor = Editor(
      editables: {Editor.documentKey: _document, Editor.composerKey: _composer},
      requestHandlers: [
        joinLines,
        pasteLines,
        ...defaultRequestHandlers.cast<EditRequestHandler>(),
      ],
      // No Markdown shortcuts: lines stay as typed.
      reactionPipeline: [],
    )..addListener(FunctionalEditListener(_onTransaction));
    note.addListener(_scheduleSync);
  }

  final NoteDocumentController note;

  /// The user removed items; [undo] brings them back.
  final void Function(String message, EditUndo undo) onRemoved;

  /// The caret went into a line the user added with a button: the editor
  /// should take the keyboard.
  final VoidCallback onCaretPlaced;

  late final Editor editor;
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;
  final _ids = LineNodes();

  /// Whether the editor is being made to show the note: its transactions
  /// are not the user's.
  bool _syncing = false;
  bool _syncScheduled = false;
  bool _disposed = false;

  /// Where the caret goes once the editor shows the note again.
  DocumentPosition? _pendingCaret;

  bool get _visual => note.mode == NoteMode.visual;

  /// The line the caret is in, if any.
  LineId? get caretLine => switch (_composer.selection) {
    final selection? => _ids.lineOf(selection.extent.nodeId),
    null => null,
  };

  /// See [NoteDocumentController.startList]; the caret goes into the new
  /// item.
  void startList() => _caretInto(note.startList(at: caretLine));

  /// Puts the caret at the start of the first line.
  void placeCaretAtStart() {
    final first = _document.firstOrNull;
    if (first == null) return;
    editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: first.id,
            nodePosition: first.beginningPosition,
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  List<DocumentNode> _targetNodes() {
    _ids.retain({for (final line in note.lines.lines) line.id});
    return editNodes(note.entries, note.lines, _ids, visual: _visual);
  }

  void _onTransaction(List<EditEvent> events) {
    if (_syncing) return;
    final (:edits, :added) = transactionEdits(events, _document, _ids);
    if (edits.isEmpty) return;
    final lines = note.applyEdits(edits);
    for (final (index, node) in added.indexed) {
      _ids.link(node, lines[index]);
    }
  }

  /// Syncs once the current transaction and its listeners are done.
  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    scheduleMicrotask(_sync);
  }

  void _sync() {
    _syncScheduled = false;
    if (_disposed) return;
    _syncing = true;
    try {
      syncDocument(editor, _targetNodes());
    } finally {
      _syncing = false;
    }
    if (_pendingCaret case final caret?) {
      _pendingCaret = null;
      // Once the new line is laid out: super_editor draws the caret of a
      // fresh selection before laying out a line added in the same frame.
      SchedulerBinding.instance
        ..addPostFrameCallback((_) => _placeCaret(caret))
        ..scheduleFrame();
    }
  }

  void _placeCaret(DocumentPosition caret) {
    if (_disposed || _document.getNodeById(caret.nodeId) == null) return;
    editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(position: caret),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);
    onCaretPlaced();
  }

  void _caretInto(LineId line) {
    _pendingCaret = DocumentPosition(
      nodeId: _ids.nodeOf(line),
      nodePosition: const TextNodePosition(offset: 0),
    );
    _scheduleSync();
  }

  LineId? _lineOfNode(String nodeId) => _ids.lineOf(nodeId);

  @override
  void indent(String nodeId) {
    if (_lineOfNode(nodeId) case final line?) note.indent(line);
  }

  @override
  void outdent(String nodeId) {
    if (_lineOfNode(nodeId) case final line?) note.outdent(line);
  }

  @override
  void delete(String nodeId) {
    if (_lineOfNode(nodeId) case final line?) {
      onRemoved('Item deleted', note.remove(line));
    }
  }

  @override
  void move(String nodeId, {required String target, required bool below}) {
    final (line, targetLine) = (_lineOfNode(nodeId), _lineOfNode(target));
    if (line == null || targetLine == null) return;
    note.move(line, target: targetLine, below: below);
  }

  @override
  void toggleDone(LineId list) => note.toggleCollapsed(list);

  @override
  void addItem(AddItemEntry buttons, ListKind kind) =>
      _caretInto(note.addItem(buttons, kind));

  @override
  void showRaw(LineId first) => note.showRaw(first);

  void dispose() {
    _disposed = true;
    note.removeListener(_scheduleSync);
    editor.dispose();
  }
}
