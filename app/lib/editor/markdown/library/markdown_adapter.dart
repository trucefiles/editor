import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

import '../../editor_gate.dart';
import '../../library/document_patch.dart';

/// Connects the library's [editor], one plain text node per line, to the
/// editor owner behind [_gate] in Markdown edit. The library edits the
/// lines itself, as plain text; after each transaction that changed
/// them, the change re-reads the lines' tree (see
/// [md.DocumentTree.withLines]) and the owner gets the new text. A text
/// from elsewhere shows at once, the caret kept on its line.
final class MarkdownAdapter {
  MarkdownAdapter(this._gate)
    : _tree = md.DocumentTree.read(_ownerText(_gate)) {
    _document = MutableDocument(
      nodes: [
        for (final line in _tree.lines)
          _lineNode(_newNodeId(line.id), line.text),
      ],
    );
    editor = Editor(
      editables: {Editor.documentKey: _document, Editor.composerKey: composer},
      requestHandlers: [_handle, ..._libraryHandlers],
      reactionPipeline: [],
    )..addListener(FunctionalEditListener(_onTransactionEnd));
    _gate.addListener(_onOwnerChanged);
  }

  final EditorGate _gate;
  late final Editor editor;
  late final MutableDocument _document;
  final composer = MutableDocumentComposer();

  /// The lines as the library holds them, read.
  md.DocumentTree _tree;

  /// The line each node shows; a node the library just made has none.
  final _lineOf = <String, md.LineId>{};
  int _nextNodeId = 0;

  /// The text sent to the owner last, so its echo is no news.
  String? _sent;

  /// Whether our own patch runs: its changes are no edits.
  bool _patching = false;

  Document get document => _document;

  /// The lines' tree, for highlighting.
  md.DocumentTree get tree => _tree;

  final _treeChanged = _Changes();

  /// Tells of each change of [tree].
  Listenable get treeChanged => _treeChanged;

  /// The highlights of the line node [nodeId] shows; none for one the
  /// library just made.
  List<md.HighlightSpan> highlightsOf(String nodeId) =>
      switch (_lineOf[nodeId]) {
        final line? => md.highlightsOf(_tree, line),
        null => const [],
      };

  /// Where the link at [position] leads, if its text is part of one.
  String? linkAt(DocumentPosition position) => switch (position.nodePosition) {
    TextNodePosition(:final offset) =>
      highlightsOf(position.nodeId)
          .where((span) => span.start <= offset && offset < span.end)
          .map((span) => span.highlight)
          .whereType<md.LinkHighlight>()
          .lastOrNull
          ?.destination,
    _ => null,
  };

  /// The line node [nodeId] shows; `null` for one the library just made.
  md.LineId? lineOf(String nodeId) => _lineOf[nodeId];

  static String _ownerText(EditorGate gate) => switch (gate.state.content) {
    md.MarkdownContent(:final text) => text,
    md.FormattedContent() => '',
  };

  String _newNodeId(md.LineId line) {
    final id = 'line-${_nextNodeId++}';
    _lineOf[id] = line;
    return id;
  }

  static DocumentNode _lineNode(String id, String text) =>
      ParagraphNode(id: id, text: AttributedText(text));

  // Library edits.

  /// Our patch, and pastes as plain text, its lines made at the end of
  /// the transaction like any text with line breaks; the library's
  /// handlers take every other request.
  EditCommand? _handle(Editor editor, EditRequest request) => switch (request) {
    _PatchRequest(:final nodes, :final selection) => PatchCommand(
      nodes,
      selection: selection,
    ),
    PasteEditorRequest(:final content, :final pastePosition) =>
      InsertTextCommand(
        documentPosition: pastePosition,
        textToInsert: content,
        attributions: const {},
      ),
    _ => null,
  };

  /// The lines the transaction's [changes] touched, re-read; the owner
  /// gets the text. A node that came to hold line breaks (pasted text, or
  /// text an input method put in) is split into its lines.
  void _onTransactionEnd(List<EditEvent> changes) {
    if (_patching) return;
    final edits = changes
        .whereType<DocumentEdit>()
        .map((edit) => edit.change)
        .whereType<NodeDocumentChange>()
        .toList();
    if (edits.isEmpty) return;
    final touched = {
      for (final edit in edits)
        if (edit is! NodeRemovedEvent &&
            _document.getNodeById(edit.nodeId) != null)
          edit.nodeId,
    };
    final oldLines = <md.LineId>{
      for (final edit in edits)
        if (edit is NodeRemovedEvent) ?_lineOf.remove(edit.nodeId),
      for (final id in touched) ?_lineOf[id],
    };
    final oldIndexes = [for (final line in oldLines) _tree.indexOf(line)];
    final newIndexes = [
      for (final id in touched) _document.getNodeIndexById(id),
    ];
    if (oldIndexes.isEmpty && newIndexes.isEmpty) return;
    final start = [...oldIndexes, ...newIndexes].min;
    final (oldCount, newCount) = (_tree.lines.length, _document.nodeCount);
    final tail = [
      oldCount - (oldIndexes.maxOrNull ?? start - 1) - 1,
      newCount - (newIndexes.maxOrNull ?? start - 1) - 1,
    ].min;
    final nodes = _document.toList().sublist(start, newCount - tail);
    final caret = _caretOf(composer.selection);
    _tree = _tree.withLines(start, oldCount - tail, [
      for (final node in nodes) (id: _lineOf[node.id], text: _textOf(node)),
    ]);
    if (_tree.lines.length == newCount) {
      // Nodes and lines go together by position; a line's node is new
      // only where the line is.
      for (final (index, node) in nodes.indexed) {
        _lineOf[node.id] = _tree.lines[start + index].id;
      }
    } else {
      _show(caret);
    }
    _treeChanged.changed();
    final text = _sent = _tree.text;
    _gate.send((now) => md.EditText(text, revision: now.revision));
  }

  // Text from elsewhere.

  /// Shows the owner's text when it is not what was sent: the lines that
  /// stayed keep their nodes; the caret goes where the owner says (after
  /// an undo, to the change), else it stays on its line.
  void _onOwnerChanged() {
    final (text, offset) = switch (_gate.state.content) {
      md.MarkdownContent(:final text, :final caret) => (text, caret),
      md.FormattedContent() => (null, null),
    };
    if (text == null || identical(text, _sent) || text == _tree.text) return;
    final caret = switch (offset) {
      final offset? => _caretAtOffset(text, offset),
      null => _caretOf(composer.selection),
    };
    _tree = _tree.withText(text);
    _show(caret);
    _treeChanged.changed();
  }

  /// The line and offset of the caret at [offset] in [text].
  static _Caret _caretAtOffset(String text, int offset) {
    final lines = md.splitLines(text.substring(0, offset));
    return (line: lines.length - 1, offset: lines.last.text.length);
  }

  // Showing the lines.

  /// Makes the nodes show [_tree]'s lines: a line's node stays, other
  /// lines get new ones; the caret goes to [caret], kept within the
  /// lines.
  void _show(_Caret? caret) {
    final nodeOf = {
      for (final MapEntry(:key, :value) in _lineOf.entries) value: key,
    };
    final targets = [
      for (final line in _tree.lines)
        _target(nodeOf[line.id] ?? 'line-${_nextNodeId++}', line),
    ];
    _lineOf
      ..clear()
      ..addAll({
        for (final (index, line) in _tree.lines.indexed)
          targets[index].id: line.id,
      });
    final selection = switch (caret) {
      (:final line, :final offset) => _caretAt(
        _tree.lines[line.clamp(0, _tree.lines.length - 1)],
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

  TargetNode _target(String id, md.Line line) => (
    id: id,
    shows: (node) => node is TextNode && _textOf(node) == line.text,
    build: () => _lineNode(id, line.text),
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
        .map((node) => md.splitLines(_textOf(node)).length)
        .sum;
    final ownText = _textOf(_document.getNodeAt(index)!);
    final own = md.splitLines(
      ownText.substring(0, offset.clamp(0, ownText.length)),
    );
    return (line: linesBefore + own.length - 1, offset: own.last.text.length);
  }

  static DocumentSelection _caretAt(md.Line line, String nodeId, int offset) =>
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: nodeId,
          nodePosition: TextNodePosition(
            offset: offset.clamp(0, line.text.length),
          ),
        ),
      );

  static String _textOf(DocumentNode node) =>
      (node as TextNode).text.toPlainText();

  void dispose() {
    _gate.removeListener(_onOwnerChanged);
    _treeChanged.dispose();
    editor.dispose();
  }
}

/// The library's own request handlers.
final _libraryHandlers = defaultRequestHandlers.cast<EditRequestHandler>();

/// A caret on line [line] of the tree, at [offset] in it.
typedef _Caret = ({int line, int offset});

/// Shows the tree's lines; see [PatchCommand].
final class _PatchRequest implements EditRequest {
  const _PatchRequest(this.nodes, {required this.selection});

  final List<TargetNode> nodes;
  final DocumentSelection? selection;
}

/// Tells its listeners of a change.
final class _Changes extends ChangeNotifier {
  void changed() => notifyListeners();
}
