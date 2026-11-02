import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart' show splitLines, unchangedEnds;

import '../../library/document_patch.dart';
import '../../library/own_paste.dart';
import '../edited_text.dart';

/// Connects the library's [editor], one plain text node per line, to the
/// text [_text] edits. The library edits the lines itself, as plain text;
/// after each transaction that changed them, [_text] gets the new [text];
/// a caret the user moved, [_text] hears of too. A text from elsewhere
/// shows at once: the lines that stayed at its start and end keep their
/// nodes, and the caret stays on its line.
final class LinesAdapter {
  LinesAdapter(this._text) : _shown = _text.shown?.text ?? '' {
    _document = MutableDocument(
      nodes: [
        for (final line in splitLines(_shown)) _lineNode(_newNodeId(), line),
      ],
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
    _PatchRequest(:final nodes, :final selection) => PatchCommand(
      nodes,
      selection: selection,
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

  /// The text after a transaction that changed the lines; the edited
  /// text gets it. A node that came to hold line breaks (pasted text, or
  /// text an input method put in) is split into its lines. A transaction
  /// that only moved the caret tells the edited text so.
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
    final lines = nodes.expand(splitLines).toList();
    if (lines.length != nodes.length) {
      _show(lines, _caretOf(composer.selection));
    }
    final text = lines.join('\n');
    if (text == _shown) return;
    _shown = text;
    _lastChange = LinesChange.edited;
    _linesChanged.changed();
    _text.edit(text, pasted: changes.any((change) => change is _Pasted));
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
      null => _caretOf(composer.selection),
    };
    _shown = text;
    _show(splitLines(text), caret);
    _lastChange = LinesChange.replaced;
    _linesChanged.changed();
  }

  /// The line and offset of the caret at [offset] in [text].
  static _Caret _caretAtOffset(String text, int offset) {
    final lines = splitLines(text.substring(0, offset));
    return (line: lines.length - 1, offset: lines.last.length);
  }

  // Showing the lines.

  /// Makes the nodes show [lines]: the nodes of the lines that stayed at
  /// the start and end stay, other lines get new ones; the caret goes to
  /// [caret], kept within the lines.
  void _show(List<String> lines, _Caret? caret) {
    final nodes = _document.toList();
    final same = unchangedEnds([
      for (final node in nodes) _textOf(node),
    ], lines);
    final targets = [
      for (final (index, line) in lines.indexed)
        _target(switch (index) {
          _ when index < same.start => nodes[index].id,
          _ when index >= lines.length - same.end =>
            nodes[index - lines.length + nodes.length].id,
          _ => _newNodeId(),
        }, line),
    ];
    final selection = switch (caret) {
      (:final line, :final offset) => _caretAt(
        lines[line.clamp(0, lines.length - 1)],
        targets[line.clamp(0, targets.length - 1)].id,
        offset,
      ),
      null => null,
    };
    _patching = true;
    try {
      editor.execute([_PatchRequest(targets, selection: selection)]);
    } finally {
      _patching = false;
    }
  }

  TargetNode _target(String id, String line) => (
    id: id,
    shows: (node) => node is TextNode && _textOf(node) == line,
    build: () => _lineNode(id, line),
  );

  /// The line and offset of [selection]'s caret, counting the lines in
  /// each node's text.
  _Caret? _caretOf(DocumentSelection? selection) {
    if (selection == null) return null;
    final index = _document.getNodeIndexById(selection.extent.nodeId);
    final offset = switch (selection.extent.nodePosition) {
      TextNodePosition(:final offset) => offset,
      _ => 0,
    };
    if (index < 0) return null;
    final linesBefore = _document
        .toList()
        .take(index)
        .map((node) => splitLines(_textOf(node)).length)
        .sum;
    final ownText = _textOf(_document.getNodeAt(index)!);
    final own = splitLines(
      ownText.substring(0, offset.clamp(0, ownText.length)),
    );
    return (line: linesBefore + own.length - 1, offset: own.last.length);
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
  const _PatchRequest(this.nodes, {required this.selection});

  final List<TargetNode> nodes;
  final DocumentSelection? selection;
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
