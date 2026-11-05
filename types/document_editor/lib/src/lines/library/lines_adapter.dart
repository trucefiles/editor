import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart'
    show TextChange, TextEdit, splitLines, textChange, unchangedEnds;

import '../../library/document_patch.dart';
import '../../library/own_clipboard.dart';
import '../edited_text.dart';

/// Connects the library's [editor], one plain text node per line, to the
/// text [_text] edits. The library edits the lines itself, as plain text;
/// after each transaction that changed them, [_text] gets the edit: the
/// new [text] and the change that made it, found among the lines that
/// changed only. A caret the user moved, [_text] hears of too. A text
/// from elsewhere shows at once: the lines that stayed at its start and
/// end keep their nodes, and the caret stays on its line.
final class LinesAdapter {
  LinesAdapter(this._text) : _shown = _text.shown?.text ?? '' {
    _lines = splitLines(_shown);
    _document = MutableDocument(
      nodes: [for (final line in _lines) _lineNode(_newNodeId(), line)],
    );
    editor = Editor(
      editables: {Editor.documentKey: _document, Editor.composerKey: composer},
      requestHandlers: [_handle, ..._libraryHandlers],
      reactionPipeline: [],
    )..addListener(FunctionalEditListener(_onTransactionEnd));
    _text.addListener(_onTextChanged);
  }

  final EditedText _text;
  late final Editor editor;
  late final MutableDocument _document;
  final composer = MutableDocumentComposer();

  /// The text the nodes show, their lines broken by `\n`.
  String _shown;

  /// The lines of [_shown], each the very string its node holds: a line
  /// the library left alone is the same object, so finding the lines an
  /// edit changed is a pointer compare per line, reading no text.
  late List<String> _lines;

  int _nextNodeId = 0;

  /// Whether our own patch runs: its changes are no edits.
  bool _patching = false;

  /// The nodes, one per line.
  Document get document => _document;

  /// The text the nodes show.
  String get text => _shown;

  /// Each node's id and the line it shows, in order.
  List<({String id, String text})> get lines => [
    for (final node in _document) (id: node.id, text: _textOf(node)),
  ];

  /// The line node [id] shows; `null` if there is no such node.
  String? lineOf(String id) => switch (_document.getNodeById(id)) {
    final node? => _textOf(node),
    null => null,
  };

  /// What changed [text] last.
  LinesChange get lastChange => _lastChange;
  LinesChange _lastChange = LinesChange.edited;

  final _linesChanged = _Changes();

  /// Tells of each change of [text]; [lastChange] says what made it.
  Listenable get linesChanged => _linesChanged;

  String _newNodeId() => 'line-${_nextNodeId++}';

  static DocumentNode _lineNode(String id, String text) =>
      ParagraphNode(id: id, text: AttributedText(text));

  // Library edits.

  /// [text] pasted over the selection, as one edit.
  void paste(String text) => editor.execute([PasteRequest(text)]);

  /// Our patch, and pastes as plain text, its lines made at the end of
  /// the transaction like any text with line breaks; the library's
  /// handlers take every other request.
  EditCommand? _handle(Editor editor, EditRequest request) => switch (request) {
    _PatchRequest(
      :final nodes,
      :final start,
      :final count,
      :final selection,
      :final byUser,
    ) =>
      PatchCommand(
        nodes,
        start: start,
        count: count,
        selection: selection,
        byUser: byUser,
      ),
    PasteRequest(:final text) => _PasteCommand([
      for (final request in plainPasteRequests(text, composer.selection))
        ?_libraryCommand(request),
    ]),
    _ => null,
  };

  EditCommand? _libraryCommand(EditRequest request) => _libraryHandlers
      .map((handler) => handler(editor, request))
      .nonNulls
      .firstOrNull;

  /// The edit a transaction that changed the lines made; the edited text
  /// gets it. A node that came to hold line breaks (pasted text, or text
  /// an input method put in) is split into its lines. A transaction that
  /// only moved the caret tells the edited text so.
  void _onTransactionEnd(List<EditEvent> changes) {
    if (_patching) return;
    final edited = changes.whereType<DocumentEdit>().any(
      (edit) => edit.change is NodeDocumentChange,
    );
    if (!edited) {
      if (changes.any(_movesCaret)) _text.caretMoved();
      return;
    }
    final nodes = [for (final node in _document) _textOf(node)];
    final same = unchangedEnds(nodes, _lines);
    final changedNodes = nodes.sublist(same.start, nodes.length - same.end);
    final changed = changedNodes.expand(splitLines).toList();
    if (changed.length != changedNodes.length) {
      final caret = _caretOf(composer.selection, same.start, changedNodes);
      _replace(same.start, changedNodes.length, changed, caret, byUser: true);
    }
    final lines = [
      ...nodes.take(same.start),
      ...changed,
      ...nodes.skip(nodes.length - same.end),
    ];
    final change = _changeOf(lines, same);
    _lines = lines;
    if (change == null) return;
    final edit = TextEdit(_shown, change);
    _shown = edit.text;
    _lastChange = LinesChange.edited;
    _linesChanged.changed();
    _text.edit(edit, pasted: changes.any((change) => change is _Pasted));
  }

  /// The change from [_lines] to [lines], whose lines outside the middle
  /// stayed as [same] says: the change of the middle lines alone, moved to
  /// their place; `null` if no line changed.
  TextChange? _changeOf(List<String> lines, ({int start, int end}) same) {
    final before = _lines.length - same.start - same.end;
    final after = lines.length - same.start - same.end;
    if (before == 0 && after == 0) return null;
    // A middle without lines on one side takes in the line next to it, so
    // that both sides join to a text.
    final widen = before == 0 || after == 0;
    final from = widen && same.start > 0 ? same.start - 1 : same.start;
    final to = widen && same.start == 0 ? same.end - 1 : same.end;
    final change = textChange(
      _lines.sublist(from, _lines.length - to).join('\n'),
      lines.sublist(from, lines.length - to).join('\n'),
    );
    final offset = _lines
        .take(from)
        .fold(from, (sum, line) => sum + line.length);
    return (
      start: offset + change.start,
      removed: change.removed,
      added: change.added,
    );
  }

  static bool _movesCaret(EditEvent change) =>
      change is SelectionChangeEvent &&
      change.newSelection != change.oldSelection;

  // Text from elsewhere.

  /// Shows the edited text when it is not what was sent: the lines that
  /// stayed keep their nodes; the caret goes where it says (after an
  /// undo, to the change), else it stays on its line.
  void _onTextChanged() {
    final (text, offset) = switch (_text.shown) {
      (:final text, :final caret) => (text, caret),
      null => (null, null),
    };
    // What shows already, e.g. the echo of an edit sent. Not compared with
    // the text sent last: undo and redo may bring that same text back.
    if (text == null || text == _shown) return;
    final caret = switch (offset) {
      final offset? => _caretAtOffset(text, offset),
      null => _caretOf(composer.selection, 0, const []),
    };
    _shown = text;
    _show(splitLines(text), caret, byUser: false);
    _lastChange = LinesChange.replaced;
    _linesChanged.changed();
  }

  /// The line and offset of the caret at [offset] in [text].
  static _Caret _caretAtOffset(String text, int offset) {
    final lines = splitLines(text.substring(0, offset));
    return (line: lines.length - 1, offset: lines.last.length);
  }

  // Showing the lines.

  /// Makes the nodes show [lines], a text from elsewhere: the nodes of the
  /// lines that stayed at the start and end stay, the lines between get
  /// new ones (see [_replace]).
  void _show(List<String> lines, _Caret? caret, {required bool byUser}) {
    final nodes = [for (final node in _document) _textOf(node)];
    final same = unchangedEnds(nodes, lines);
    final middle = lines.sublist(same.start, lines.length - same.end);
    final count = nodes.length - same.start - same.end;
    _replace(same.start, count, middle, caret, byUser: byUser);
    _lines = [
      ...nodes.take(same.start),
      ...middle,
      ...nodes.skip(nodes.length - same.end),
    ];
  }

  /// Makes the [count] nodes from [start] show [lines] instead, each in a
  /// new node; the nodes around stay untouched. The caret goes to [caret],
  /// a line of the text after, kept within the lines; [byUser] as for
  /// [PatchCommand].
  void _replace(
    int start,
    int count,
    List<String> lines,
    _Caret? caret, {
    required bool byUser,
  }) {
    final targets = [for (final line in lines) _target(_newNodeId(), line)];
    final last = _document.nodeCount - count + lines.length - 1;
    ({String id, String text}) lineAt(int line) => switch (line) {
      _ when line < start => _lineAt(line),
      _ when line < start + lines.length => (
        id: targets[line - start].id,
        text: lines[line - start],
      ),
      _ => _lineAt(line - lines.length + count),
    };
    final selection = switch (caret) {
      (:final line, :final offset) => switch (lineAt(line.clamp(0, last))) {
        (:final id, :final text) => _caretAt(text, id, offset),
      },
      null => null,
    };
    _patching = true;
    try {
      editor.execute([
        _PatchRequest(
          targets,
          start: start,
          count: count,
          selection: selection,
          byUser: byUser,
        ),
      ]);
    } finally {
      _patching = false;
    }
  }

  /// The id and line of the node at [index].
  ({String id, String text}) _lineAt(int index) =>
      switch (_document.getNodeAt(index)!) {
        final node => (id: node.id, text: _textOf(node)),
      };

  TargetNode _target(String id, String line) => (
    id: id,
    shows: (node) => node is TextNode && _textOf(node) == line,
    build: () => _lineNode(id, line),
  );

  /// The line and offset of [selection]'s caret in the text the nodes
  /// show; [split] are the texts of the nodes from [from] on that may hold
  /// line breaks, every other node holds one line.
  _Caret? _caretOf(DocumentSelection? selection, int from, List<String> split) {
    if (selection == null) return null;
    final index = _document.getNodeIndexById(selection.extent.nodeId);
    final offset = switch (selection.extent.nodePosition) {
      TextNodePosition(:final offset) => offset,
      _ => 0,
    };
    if (index < 0) return null;
    final breaksBefore = split
        .take((index - from).clamp(0, split.length))
        .fold(0, (sum, text) => sum + splitLines(text).length - 1);
    if (index < from || index >= from + split.length) {
      return (line: index + breaksBefore, offset: offset);
    }
    final own = split[index - from];
    final ahead = splitLines(own.substring(0, offset.clamp(0, own.length)));
    return (
      line: index + breaksBefore + ahead.length - 1,
      offset: ahead.last.length,
    );
  }

  static DocumentSelection _caretAt(String line, String nodeId, int offset) =>
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: TextNodePosition(offset: offset.clamp(0, line.length)),
        ),
      );

  /// The line [node] shows.
  static String _textOf(DocumentNode node) =>
      (node as TextNode).text.toPlainText();

  void dispose() {
    _text.removeListener(_onTextChanged);
    _linesChanged.dispose();
    editor.dispose();
  }
}

/// What changed a line editor's text.
enum LinesChange {
  /// The user, in the editor.
  edited,

  /// A text from elsewhere, e.g. an undo or a change on another device.
  replaced,
}

/// The library's own request handlers.
final _libraryHandlers = defaultRequestHandlers.cast<EditRequestHandler>();

/// A caret on line [line], at [offset] in it.
typedef _Caret = ({int line, int offset});

/// Shows the lines; see [PatchCommand].
final class _PatchRequest implements EditRequest {
  const _PatchRequest(
    this.nodes, {
    required this.start,
    required this.count,
    required this.selection,
    required this.byUser,
  });

  final List<TargetNode> nodes;
  final int start;
  final int count;
  final DocumentSelection? selection;
  final bool byUser;
}

/// Runs [commands], a paste, and tells so with [_Pasted].
final class _PasteCommand extends EditCommand {
  _PasteCommand(this.commands);

  final List<EditCommand> commands;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    commands.forEach(executor.executeCommand);
    executor.logChanges([const _Pasted()]);
  }
}

/// The transaction was a paste.
final class _Pasted extends EditEvent {
  const _Pasted();
}

/// Tells its listeners of a change.
final class _Changes extends ChangeNotifier {
  void changed() => notifyListeners();
}
