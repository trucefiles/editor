import 'dart:async';
import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show TextAffinity;
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';

import '../note_document_controller.dart';
import 'components/display_actions.dart';
import 'components/item_actions.dart';
import 'key_actions.dart';
import 'note_nodes.dart';
import 'note_requests.dart';
import 'sync_document.dart';
import 'text_changes.dart';

/// Connects a super_editor [editor] to the [note] it edits. The editor
/// only shows the note and takes input: each text edit it makes goes to
/// [note] as a change of views' text (see [textChangeOf]), and the keys
/// that change structure go to [note] as what they do (see
/// [noteRequests]); whenever [note] changes, the editor's document is
/// made to show it again, each node showing one view.
final class NoteEditorAdapter
    implements KeyActions, ItemActions, DisplayActions {
  NoteEditorAdapter(
    this.note, {
    required this.onRemoved,
    required this.onCaretPlaced,
  }) {
    _composer = MutableDocumentComposer();
    _document = MutableDocument(nodes: _targetNodes(caretLine: null));
    editor = Editor(
      editables: {Editor.documentKey: _document, Editor.composerKey: _composer},
      requestHandlers: [
        noteRequests(this),
        ...defaultRequestHandlers.cast<EditRequestHandler>(),
      ],
      // No Markdown shortcuts: text stays as typed.
      reactionPipeline: [],
    )..addListener(FunctionalEditListener(_onTransaction));
    note.addListener(_scheduleSync);
    _composer.selectionNotifier.addListener(_onSelection);
  }

  final NoteDocumentController note;

  /// The user removed items; [undo] brings them back.
  final void Function(String message, EditUndo undo) onRemoved;

  /// The caret went into an item the user added with a button: the
  /// editor should take the keyboard.
  final VoidCallback onCaretPlaced;

  late final Editor editor;
  late final MutableDocument _document;
  late final MutableDocumentComposer _composer;

  /// The view each node shows, by node id, in display order.
  Map<String, EditView> _views = const {};

  /// Whether the editor is being made to show the note: its transactions
  /// are not the user's.
  bool _syncing = false;
  bool _syncScheduled = false;
  bool _disposed = false;

  /// The empty item the editor shows as text because the caret was in it
  /// (see [LeafView.held]); it shows as an item once the caret leaves it.
  LineId? _heldLine;

  /// Where the selection goes once the editor shows the note again.
  _LineSelection? _next;

  /// Whether the editor should take the keyboard then.
  bool _focusNext = false;

  /// The view node [nodeId] shows, as the note had it when last shown;
  /// `null` for a node that shows none, e.g. a "Done" heading.
  EditView? viewOf(String nodeId) => _views[nodeId];

  /// The url of the link at [position], by the markup of its view.
  String? linkAt(DocumentPosition position) => switch ((
    _document.getNodeById(position.nodeId),
    viewOf(position.nodeId),
    position.nodePosition,
  )) {
    (final TextNode node, final view?, TextNodePosition(:final offset)) =>
      view.linkAt(node.text.toPlainText(), offset),
    _ => null,
  };

  /// Puts the caret at the start of the note.
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

  /// Turns the selected text into items of [kind], or back into text;
  /// see [NoteDocumentController.toList]. The caret stays in its place in
  /// the text, or goes into an item added for want of text to turn.
  void toList(ListKind kind) {
    LineId? added;
    _keepingSelection(() => added = note.toList(_selectedLines(), kind));
    if (added case final line?) {
      _moveCaretTo((line: line, offset: 0), focus: true);
    }
  }

  // Keys.

  @override
  void enter() => _atSelection(note.enter);

  @override
  void lineBreak() => _atSelection(note.lineBreak);

  /// The text edit [edit] at the selection: once it is collapsed.
  void _atSelection(LineCaret Function(EditView view, int offset) edit) {
    final selection = _composer.selection;
    if (selection == null) return;
    final caret = selection.isCollapsed
        ? _caretOf(selection.extent)
        : _replaceSelection('');
    if (caret == null) return;
    final view = _viewAt(caret);
    if (view == null) return;
    _next = _collapsed(edit(view, view.offsetOf(caret)!));
  }

  @override
  void joinBackward(String nodeId) {
    final view = _views[nodeId];
    if (view == null) return;
    final fallback = _caretNear(nodeId);
    final joined = note.joinBackward(view, _textViewNextTo(nodeId, -1));
    if (joined != null) _next = _collapsed(joined.caret ?? fallback);
  }

  @override
  void joinForward(String nodeId) {
    final view = _views[nodeId];
    if (view == null) return;
    final fallback = _caretNear(nodeId);
    final joined = note.joinForward(view, _textViewNextTo(nodeId, 1));
    if (joined != null) _next = _collapsed(joined.caret ?? fallback);
  }

  @override
  void paste(String text) {
    // Pasted Windows or old Mac line breaks are line breaks too: a `\r`
    // left in a line would end up in the file as a space.
    _next = _collapsed(
      _replaceSelection(text.replaceAll(_breaks, '\n'), by: note.paste),
    );
  }

  @override
  void replaceText(String nodeId, int start, int end, String text) {
    if (_views[nodeId] case final view?) {
      _next = _collapsed(_replaceIn(view, start, end, text));
    }
  }

  /// The text of [view] from [start] to [end] replaced by [text]; returns
  /// the caret after it.
  LineCaret _replaceIn(EditView view, int start, int end, String text) =>
      note.replaceText(
        (view: view, offset: start),
        (view: view, offset: end),
        text,
      );

  /// The text of the node [selection] is in replaced by what [format]
  /// makes of it, given the node's view and the selected part of its
  /// text; the selection then where [format] puts it. Does nothing for a
  /// selection across nodes or a [format] that gives `null`.
  void format(
    DocumentSelection? selection,
    FormattedText? Function(EditView view, int start, int end) format,
  ) {
    final view = _views[selection?.extent.nodeId];
    if ((selection?.base.nodePosition, selection?.extent.nodePosition, view)
        case (
          TextNodePosition(offset: final base),
          TextNodePosition(offset: final extent),
          final view?,
        )
        when selection!.base.nodeId == selection.extent.nodeId) {
      final formatted = format(view, min(base, extent), max(base, extent));
      if (formatted == null) return;
      final change = textDifference(view.text, formatted.text);
      final caret = _replaceIn(view, change.start, change.end, change.text);
      LineCaret at(int offset) =>
          _placeAfter(view, change, formatted.text, offset, caret: caret);
      _next = (base: at(formatted.start), extent: at(formatted.end));
    }
  }

  /// Where [offset] in [after] is in the note, now that [change] made
  /// [after] of the text of [view] and put the [caret] after the text it
  /// inserted: before the change where it was in [view]; on a line after
  /// the inserted text where it was there; else on the caret's line, as
  /// far from the caret as in [after].
  static LineCaret _placeAfter(
    EditView view,
    TextDifference change,
    String after,
    int offset, {
    required LineCaret caret,
  }) {
    if (offset <= change.start) return view.caretAt(offset);
    final inserted = change.start + change.text.length;
    final (from, to) = offset < inserted
        ? (offset, inserted)
        : (inserted, offset);
    return switch ((
      after.substring(from, to).contains('\n'),
      offset > inserted,
    )) {
      (false, _) => (
        line: caret.line,
        offset: caret.offset + offset - inserted,
      ),
      (true, true) => view.caretAt(offset - inserted + change.end),
      (true, false) => caret,
    };
  }

  @override
  bool indentAtCaret({required bool outdent}) {
    final item = switch (_views[_composer.selection?.extent.nodeId]) {
      final LeafView view => view.item,
      _ => null,
    };
    if (item == null) return false;
    outdent ? this.outdent(item) : indent(item);
    return true;
  }

  // Items.

  @override
  void toggle(LineId item) => note.toggle(item);

  @override
  void indent(LineId item) => _keepingSelection(() => note.indent(item));

  @override
  void outdent(LineId item) => _keepingSelection(() => note.outdent(item));

  @override
  void delete(LineId item) => onRemoved('Item deleted', note.remove(item));

  @override
  void move(LineId item, {required LineId target, required bool below}) =>
      _keepingSelection(() => note.move(item, target: target, below: below));

  // Display.

  @override
  void toggleDone(LineId list) => note.toggleCollapsed(list);

  @override
  void addItem(AddItemEntry button) =>
      _moveCaretTo((line: note.addItem(button), offset: 0), focus: true);

  @override
  void showRaw(LineId table) {
    note.rawTable = table;
    _moveCaretTo((line: table, offset: 0), focus: true);
  }

  // Edits.

  void _onTransaction(List<EditEvent> events) {
    if (_syncing || !events.any((event) => event is DocumentEdit)) return;
    final change = textChangeOf(_document, _views);
    if (change == null) return;
    final caret = note.replaceText(
      change.from,
      change.to,
      change.text,
      removed: change.removed,
    );
    // A selection the edit left stays as it is in the text.
    if (_composer.selection?.isCollapsed ?? true) _next = _collapsed(caret);
    // The edit is in the views already, also before the editor shows the
    // note again: a next edit before then counts from it.
    _views = _viewsOf(
      caretLine: (_next?.extent ?? _caretOf(_composer.selection?.extent))?.line,
    );
  }

  /// The selected text replaced by [text], [by] a text edit of the note;
  /// returns the caret after it.
  LineCaret? _replaceSelection(String text, {_TextEdit? by}) {
    final selection = _composer.selection;
    if (selection == null) return null;
    final range = selection.normalize(_document);
    final (from, to) = (_placeOf(range.start), _placeOf(range.end));
    if (from == null || to == null) return null;
    final ids = _views.keys.toList();
    final first = ids.indexOf(range.start.nodeId) + 1;
    final last = ids.indexOf(range.end.nodeId);
    return (by ?? note.replaceText)(
      from,
      to,
      text,
      removed: [
        for (final id in ids.sublist(first, max(first, last))) _views[id]!,
      ],
    );
  }

  /// [position] as a place in the view its node shows; one at a drawn
  /// table's edge is at the start or end of its text.
  ViewPlace? _placeOf(DocumentPosition position) {
    final view = _views[position.nodeId];
    if (view == null) return null;
    return switch (position.nodePosition) {
      TextNodePosition(:final offset) => (view: view, offset: offset),
      UpstreamDownstreamNodePosition(:final affinity) => (
        view: view,
        offset: affinity == TextAffinity.upstream ? 0 : view.text.length,
      ),
      _ => null,
    };
  }

  /// [position] as a place in its line; `null` if it is in no text.
  LineCaret? _caretOf(DocumentPosition? position) =>
      switch ((position, _views[position?.nodeId])) {
        (
          DocumentPosition(nodePosition: TextNodePosition(:final offset)),
          final view?,
        ) =>
          view.caretAt(offset),
        _ => null,
      };

  /// The view of the text node [step] nodes away from node [nodeId], if
  /// that one is text: the text shown right above or below it.
  EditView? _textViewNextTo(String nodeId, int step) {
    final node = step < 0
        ? _document.getNodeBeforeById(nodeId)
        : _document.getNodeAfterById(nodeId);
    return node is TextNode ? _views[node.id] : null;
  }

  /// Where the caret goes if node [nodeId] goes: the start of the next
  /// text, else the end of the text before.
  LineCaret? _caretNear(String nodeId) {
    final ids = [
      for (final node in _document)
        if (node is TextNode && _views.containsKey(node.id)) node.id,
    ];
    final index = ids.indexOf(nodeId);
    final next = ids.elementAtOrNull(index + 1);
    final previous = index > 0 ? ids[index - 1] : null;
    return switch ((next, previous)) {
      (final next?, _) => _views[next]!.caretAt(0),
      (_, final previous?) => _views[previous]!.caretAt(
        _views[previous]!.text.length,
      ),
      _ => null,
    };
  }

  /// The lines the selection spans, as the editor shows them: lines
  /// shown elsewhere (e.g. in the Done section) or not at all are not in
  /// it.
  List<LineId> _selectedLines() {
    final selection = _composer.selection;
    final shown = [
      for (final view in _views.values)
        for (final line in view.lines) line.line.id,
    ];
    final ends = [
      ?_caretOf(selection?.base),
      ?_caretOf(selection?.extent),
    ].map((caret) => shown.indexOf(caret.line)).toList()..sort();
    if (ends.isEmpty || ends.first < 0) return const [];
    return shown.sublist(ends.first, ends.last + 1);
  }

  /// [caret] as a place in its line's content, which stays while the
  /// line's prefix changes.
  ({LineId line, int offset})? _inContent(LineCaret caret) =>
      switch (_viewAt(caret)) {
        final view? => (
          line: caret.line,
          offset:
              caret.offset -
              view.lines.firstWhere((line) => line.line.id == caret.line).start,
        ),
        null => null,
      };

  LineCaret? _fromContent(({LineId line, int offset}) place) => switch (_viewAt(
    (line: place.line, offset: 0),
  )) {
    final view? => (
      line: place.line,
      offset:
          view.lines.firstWhere((line) => line.line.id == place.line).start +
          place.offset,
    ),
    null => null,
  };

  /// The view of the note as it is now that shows [caret]'s line.
  EditView? _viewAt(LineCaret caret) => [
    for (final entry in note.entries)
      if (note.viewOf(entry, caretLine: caret.line) case final view?
          when view.lines.any((line) => line.line.id == caret.line))
        view,
  ].firstOrNull;

  /// Runs [action], keeping the selection where it is in its lines'
  /// content.
  void _keepingSelection(void Function() action) {
    final selection = _composer.selection;
    final ends = [
      for (final end in [selection?.base, selection?.extent])
        if (_caretOf(end) case final caret?) _inContent(caret),
    ];
    action();
    if (ends case [final base?, final extent?]) {
      if ((_fromContent(base), _fromContent(extent)) case (
        final base?,
        final extent?,
      )) {
        _next = (base: base, extent: extent);
      }
    }
  }

  void _moveCaretTo(LineCaret caret, {required bool focus}) {
    _next = (base: caret, extent: caret);
    _focusNext = focus;
    _scheduleSync();
  }

  // Showing the note.

  Map<String, EditView> _viewsOf({required LineId? caretLine}) => {
    for (final entry in note.entries)
      nodeIdOf(entry): ?note.viewOf(entry, caretLine: caretLine),
  };

  List<DocumentNode> _targetNodes({required LineId? caretLine}) {
    _views = _viewsOf(caretLine: caretLine);
    _heldLine = [
      for (final view in _views.values)
        if (view case LeafView(held: true)) view.id,
    ].firstOrNull;
    return [
      for (final entry in note.entries)
        nodeOf(entry, _views[nodeIdOf(entry)], note.document),
    ];
  }

  /// [selection] in [nodes]; `null` unless both its ends are in text
  /// they show.
  DocumentSelection? _selectionAt(
    _LineSelection selection,
    List<DocumentNode> nodes,
  ) => switch ((
    _positionAt(selection.base, nodes),
    _positionAt(selection.extent, nodes),
  )) {
    (final base?, final extent?) => DocumentSelection(
      base: base,
      extent: extent,
    ),
    _ => null,
  };

  /// [caret] in the one of [nodes] that shows its line as text; `null` if
  /// none does.
  DocumentPosition? _positionAt(LineCaret caret, List<DocumentNode> nodes) => [
    for (final node in nodes)
      if ((node, _views[node.id]?.offsetOf(caret)) case (
        TextNode(),
        final offset?,
      ))
        DocumentPosition(
          nodeId: node.id,
          nodePosition: TextNodePosition(offset: offset),
        ),
  ].firstOrNull;

  /// Shows a held item as the item it is, and a table shown as its text
  /// drawn again, once the caret leaves it.
  void _onSelection() {
    if (_syncing) return;
    final line = _caretOf(_composer.selection?.extent)?.line;
    if (_heldLine != null && line != _heldLine) _scheduleSync();
    if ((note.rawTable, line) case (final table?, final line?)
        when note.document.leafOf(line).id != table) {
      note.rawTable = null;
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
    final selection = switch ((_next, _composer.selection)) {
      (final next?, _) => next,
      (null, final current?) => switch ((
        _caretOf(current.base),
        _caretOf(current.extent),
      )) {
        (final base?, final extent?) => (base: base, extent: extent),
        _ => null,
      },
      _ => null,
    };
    final focus = _focusNext;
    _next = null;
    _focusNext = false;
    final nodes = _targetNodes(caretLine: selection?.extent.line);
    final at = selection == null ? null : _selectionAt(selection, nodes);
    _syncing = true;
    try {
      syncDocument(editor, nodes, selection: focus ? null : at);
    } finally {
      _syncing = false;
    }
    if (at == null || !focus) return;
    // Once the new line is laid out: super_editor draws the caret of a
    // fresh selection before laying out a line added in the same frame.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (_disposed || _document.getNodeById(at.extent.nodeId) == null) {
          return;
        }
        editor.execute([
          ChangeSelectionRequest(
            at,
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);
        onCaretPlaced();
      })
      ..scheduleFrame();
  }

  void dispose() {
    _disposed = true;
    note.removeListener(_scheduleSync);
    _composer.selectionNotifier.removeListener(_onSelection);
    editor.dispose();
  }
}

final _breaks = RegExp('\r\n?');

/// A text edit of the note from one place to another, e.g.
/// [NoteDocumentController.replaceText]; returns the caret after it.
typedef _TextEdit = LineCaret Function(
  ViewPlace from,
  ViewPlace to,
  String text, {
  Iterable<EditView> removed,
});

/// A selection as places in lines.
typedef _LineSelection = ({LineCaret base, LineCaret extent});

/// The selection of just [caret], if any.
_LineSelection? _collapsed(LineCaret? caret) =>
    caret == null ? null : (base: caret, extent: caret);
