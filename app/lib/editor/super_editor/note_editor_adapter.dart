import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../note_document_controller.dart';
import 'components/display_actions.dart';
import 'components/line_actions.dart';
import 'enter_at_item_start.dart';
import 'join_lines.dart';
import 'line_nodes.dart';
import 'note_nodes.dart';
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
    _composer = MutableDocumentComposer();
    _document = MutableDocument(nodes: _targetNodes());
    editor = Editor(
      editables: {Editor.documentKey: _document, Editor.composerKey: _composer},
      requestHandlers: [
        joinLines,
        enterAtItemStart,
        pasteLines,
        ...defaultRequestHandlers.cast<EditRequestHandler>(),
      ],
      // No Markdown shortcuts: lines stay as typed.
      reactionPipeline: [],
    )..addListener(FunctionalEditListener(_onTransaction));
    note.addListener(_scheduleSync);
    _composer.selectionNotifier.addListener(_onSelection);
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

  /// The item the editor shows as text because the caret was in it (see
  /// [LineView.held]); it shows as an item once the caret leaves it.
  LineId? _heldLine;

  /// Where the caret goes once the editor shows the note again.
  DocumentPosition? _pendingCaret;

  /// The caret after the user's last edit, as a place in its line: kept
  /// when the line shows in another kind of node, such as a paragraph that
  /// became a list item.
  LineCaret? _typedCaret;

  /// The line the caret is in, if any.
  LineId? get caretLine => switch (_composer.selection) {
    final selection? => _ids.lineOf(selection.extent.nodeId),
    null => null,
  };

  /// Turns the selected lines into items of [kind], or back into text;
  /// see [NoteDocumentController.toList]. The caret stays in its place in
  /// the text, or goes into an item added for want of lines to turn.
  void toList(ListKind kind) {
    final (before, caret) = (note.lines, _caret());
    final added = note.toList(_selectedLines(), kind);
    if (added != null) return _caretInto(added);
    if (caret != null) _typedCaret = before.caretIn(note.lines, caret);
  }

  /// The lines the selection spans, in order.
  List<LineId> _selectedLines() {
    final selection = _composer.selection;
    if (selection == null) return const [];
    return [
      for (final node in _document.getNodesInside(
        selection.base,
        selection.extent,
      ))
        ?_ids.lineOf(node.id),
    ];
  }

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
    final lines = note.lines;
    _ids.retain({for (final line in lines.lines) line.id});
    final byId = {for (final line in lines.lines) line.id: line};
    final views = {
      for (final entry in note.entries)
        if (entry case LineEntry(:final id))
          id: _viewOf(byId[id]!, caretLine: caretLine),
    };
    _heldLine = views.values.where((view) => view.held).firstOrNull?.id;
    return [
      for (final entry in note.entries)
        switch (entry) {
          LineEntry(:final id) => lineNode(
            _ids.nodeOf(id),
            views[id]!,
            AttributedText(views[id]!.text),
          ),
          _ => displayNode(entry, byId),
        },
    ];
  }

  /// Shows a held line as the item it is once the caret leaves it.
  void _onSelection() {
    if (_heldLine != null && caretLine != _heldLine) _scheduleSync();
  }

  void _onTransaction(List<EditEvent> events) {
    if (_syncing) return;
    final (:edits, :added) = transactionEdits(events, _document, _ids);
    if (edits.isEmpty) return;
    final lines = note.applyEdits(edits);
    for (final (index, node) in added.indexed) {
      _ids.link(node, lines[index]);
    }
    _typedCaret = _caret();
  }

  /// The collapsed caret as a place in its line.
  LineCaret? _caret() {
    final selection = _composer.selection;
    if (selection == null || !selection.isCollapsed) return null;
    final position = selection.extent;
    final line = _line(_ids.lineOf(position.nodeId));
    final node = _document.getNodeById(position.nodeId);
    if (line == null || node == null) return null;
    if (position.nodePosition case TextNodePosition(:final offset)) {
      return (line: line.id, offset: _textStart(node, line) + offset);
    }
    return null;
  }

  /// The caret at [caret]'s place, in the node [nodes] show its line in;
  /// `null` if that node is gone.
  DocumentSelection? _selectionAt(List<DocumentNode> nodes, LineCaret caret) {
    final nodeId = _ids.nodeOf(caret.line);
    final line = _line(caret.line);
    final node = nodes.where((node) => node.id == nodeId).firstOrNull;
    if (line == null || node is! TextNode) return null;
    final offset = caret.offset - _textStart(node, line);
    return DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: nodeId,
        nodePosition: TextNodePosition(
          offset: offset.clamp(0, node.text.length),
        ),
      ),
    );
  }

  /// Where the text [node] shows starts in its [line].
  int _textStart(DocumentNode node, MarkdownLine line) =>
      showsItemText(node) ? note.lines.textStartOf(line) : 0;

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
      final nodes = _targetNodes();
      final caret = _typedCaret;
      _typedCaret = null;
      syncDocument(
        editor,
        nodes,
        selection: caret == null ? null : _selectionAt(nodes, caret),
      );
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

  MarkdownLine? _line(LineId? id) => id == null ? null : note.lines.lineOf(id);

  /// How the line node [nodeId] shows its line, as the note has it now;
  /// `null` for a node that shows none, e.g. a heading.
  LineView? viewOf(String nodeId) => switch (_line(_ids.lineOf(nodeId))) {
    final line? => _viewOf(line, caretLine: _heldLine),
    null => null,
  };

  /// How [line] shows with the caret in [caretLine].
  LineView _viewOf(MarkdownLine line, {required LineId? caretLine}) =>
      LineView.of(
        note.lines,
        line,
        blocks: note.mode.showsBlocks,
        caretLine: caretLine,
      );

  /// The url of the link at [position], by the markup of its line.
  String? linkAt(DocumentPosition position) => switch ((
    _document.getNodeById(position.nodeId),
    viewOf(position.nodeId),
    position.nodePosition,
  )) {
    (final TextNode node, final view?, TextNodePosition(:final offset)) =>
      view.linkAt(node.text.toPlainText(), offset),
    _ => null,
  };

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
  void addItem(AddItemEntry button) => _caretInto(note.addItem(button));

  @override
  void showRaw(LineId first) => note.showRaw(first);

  void dispose() {
    _disposed = true;
    note.removeListener(_scheduleSync);
    _composer.selectionNotifier.removeListener(_onSelection);
    editor.dispose();
  }
}
