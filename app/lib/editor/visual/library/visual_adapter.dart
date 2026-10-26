import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

import '../../editor_gate.dart';
import '../../library/document_patch.dart';
import '../row_looks.dart';
import 'library_nodes.dart';
import 'node_ids.dart';
import 'positions.dart';

/// Connects the library's [editor] to the editor owner behind [_gate].
/// Each library request that would change content becomes one owner
/// input carrying its own range (never a diff of the library's text);
/// a transaction that only moved the selection becomes a caret move.
/// After every change of the owner's state, the library's document is
/// patched to show it: only rows whose look changed become new nodes.
final class VisualAdapter {
  VisualAdapter(this._gate, {this._addItems}) {
    editor = Editor(
      editables: {Editor.documentKey: _document, Editor.composerKey: composer},
      requestHandlers: [_handle, ..._libraryHandlers],
      reactionPipeline: [],
    )..addListener(FunctionalEditListener(_onTransactionEnd));
    _gate.addListener(_patch);
    _patch();
  }

  final EditorGate _gate;
  late final Editor editor;
  final _document = MutableDocument(nodes: []);
  final composer = MutableDocumentComposer();
  final _ids = NodeIds();
  late final _positions = Positions(_document, _ids);

  AddItemPlace? _addItems;
  md.NodeId? _folded;

  /// The executor of our command running in a library transaction: the
  /// patch runs in it, so the input method sees the patched document.
  CommandExecutor? _executor;

  /// Whether the running transaction held a content request.
  bool _contentChanged = false;

  /// The split the library expects of the next patch, after an Enter.
  ({String id, String newId})? _split;

  Document get document => _document;

  /// Where Add item buttons show; `null`: none.
  set addItems(AddItemPlace? place) {
    if (place == _addItems) return;
    _addItems = place;
    _patch();
  }

  /// The item being dragged, whose subitems fold meanwhile; `null`: none.
  set folded(md.NodeId? item) {
    if (item == _folded) return;
    _folded = item;
    _patch();
  }

  md.FormattedContent? get _shown => switch (_gate.state.content) {
    final md.FormattedContent shown => shown,
    md.MarkdownContent() => null,
  };

  /// The owner's selection as a range, where it is one.
  md.TextSelection? get selectedRange => switch (_shown?.selection) {
    final md.TextSelection range => range,
    _ => null,
  };

  /// The link at [position], if its text is part of one.
  String? linkAt(DocumentPosition position) => switch ((
    _document.getNodeById(position.nodeId),
    position.nodePosition,
  )) {
    (final node?, TextNodePosition(:final offset)) => switch (lookOf(node)) {
      TextLook(leaf: md.TextNode(:final text)) when offset < text.length =>
        text.formattingAt(offset).link?.destination,
      _ => null,
    },
    _ => null,
  };

  // Library requests.

  /// Our command for [request]: an owner input for a content request,
  /// `null` for a selection or composer request (the library's own
  /// handlers do those), a refusal for any other.
  EditCommand? _handle(Editor editor, EditRequest request) => switch (request) {
    _PatchRequest(:final nodes, :final selection) => PatchCommand(
      nodes,
      selection: selection,
    ),
    _ when _isLibrarys(request) => null,
    _ when _inRaw => _RunCommand(this, () => _rawEdit(request)),
    _ => switch (_inputFor(request)) {
      final input? => _RunCommand(this, () => _gate.send(input)),
      null => _refused(request),
    },
  };

  static EditCommand _refused(EditRequest request) {
    assert(() {
      debugPrint('Visual edit refused ${request.runtimeType}');
      return true;
    }());
    return const _Refused();
  }

  /// Whether the library's own handlers take [request]: it changes only
  /// the selection, the composing region or the view.
  static bool _isLibrarys(EditRequest request) => switch (request) {
    ChangeSelectionRequest() ||
    ClearSelectionRequest() ||
    ChangeComposingRegionRequest() ||
    ClearComposingRegionRequest() ||
    ChangeInteractionModeRequest() ||
    RemoveComposerPreferenceStylesRequest() ||
    ChangeSingleColumnLayoutComponentStylesRequest() => true,
    _ => false,
  };

  /// The input [request] stands for, built on the owner's state when it
  /// is sent; `null` for a request Visual edit refuses.
  md.EditorInput? Function(md.EditorState now)? _inputFor(
    EditRequest request,
  ) => switch (request) {
    InsertTextRequest(:final documentPosition, :final textToInsert) => _typed(
      textToInsert,
      over: DocumentSelection.collapsed(position: documentPosition),
    ),
    InsertPlainTextAtCaretRequest(:final plainText) => _typed(plainText),
    InsertCharacterAtCaretRequest(:final character) => _typed(character),
    InsertStyledTextAtCaretRequest(:final text) => _typed(text.toPlainText()),
    DeleteSelectionRequest() => _deleteRange(composer.selection),
    DeleteContentRequest(:final documentRange) => _deleteRange(
      DocumentSelection(base: documentRange.start, extent: documentRange.end),
    ),
    DeleteUpstreamRequest() ||
    DeleteUpstreamCharacterRequest() ||
    DeleteUpstreamAtBeginningOfNodeRequest() => _pressed(md.EditKey.backspace),
    DeleteDownstreamRequest() ||
    DeleteDownstreamCharacterRequest() ||
    CombineParagraphsRequest() => _pressed(md.EditKey.delete),
    InsertNewlineAtCaretRequest(:final newNodeId) => _enter(newNodeId),
    InsertSoftNewlineAtCaretRequest() => _pressed(md.EditKey.shiftEnter),
    PasteEditorRequest(:final content) => _paste(content),
    _ => null,
  };

  md.EditorInput? Function(md.EditorState) _typed(
    String text, {
    DocumentSelection? over,
  }) {
    final range = _rangeOf(over ?? composer.selection);
    return (now) => switch (range) {
      final range? => md.Typed(text, over: range, revision: now.revision),
      null => null,
    };
  }

  md.EditorInput? Function(md.EditorState) _deleteRange(
    DocumentSelection? selection,
  ) {
    final range = _rangeOf(selection);
    return (now) => switch (range) {
      final range? => md.Run(md.DeleteRange(range), revision: now.revision),
      null => null,
    };
  }

  md.EditorInput? Function(md.EditorState) _pressed(md.EditKey key) =>
      (now) => md.Pressed(key, revision: now.revision);

  md.EditorInput? Function(md.EditorState) _enter(String newNodeId) {
    if (composer.selection case final selection?) {
      _split = (id: selection.extent.nodeId, newId: newNodeId);
    }
    return _pressed(md.EditKey.enter);
  }

  /// Text from the clipboard over the selection: the fragment copied here
  /// last, with its styles, while the clipboard still holds its text.
  md.EditorInput? Function(md.EditorState) _paste(String text) {
    final range = _rangeOf(composer.selection);
    final copied = _copied;
    return (now) => switch ((range, copied)) {
      (final range?, (:final plain, :final lines)) when plain == text => md.Run(
        md.Paste(range, lines),
        revision: now.revision,
      ),
      (final range?, _) => md.Typed(text, over: range, revision: now.revision),
      (null, _) => null,
    };
  }

  md.TextSelection? _rangeOf(DocumentSelection? selection) =>
      switch (selection == null ? null : _positions.toOwner(selection)) {
        final md.TextSelection range => range,
        _ => null,
      };

  // Keys and actions.

  /// [key] pressed: the toolbar or a keyboard shortcut.
  void press(md.EditKey key) =>
      _gate.send((now) => md.Pressed(key, revision: now.revision));

  /// Whether the caret is in an open raw block, edited as plain text.
  bool get inRaw => _inRaw;

  /// Whether an input method is composing text: keys go to it.
  bool get composing => composer.composingRegion.value != null;

  /// Removes the selected text, after [copySelection].
  void deleteSelection() => _gate.send(
    (now) => switch (_shownRange(now)) {
      final range? when !range.isCaret => md.Run(
        md.DeleteRange(range),
        revision: now.revision,
      ),
      _ => null,
    },
  );

  static md.TextSelection? _shownRange(md.EditorState state) =>
      switch (state.content) {
        md.FormattedContent(selection: final md.TextSelection range) => range,
        _ => null,
      };

  // Copy.

  /// The fragment copied here last, and the plain text the clipboard got.
  ({String plain, List<md.VisibleText> lines})? _copied;

  /// The selected text as lines with their styles, and as the plain text
  /// for the clipboard; remembered for a paste here.
  String? copySelection() {
    final (shown, range) = (_shown, selectedRange);
    if (shown == null || range == null || range.isCaret) return null;
    final lines = md.copiedLines(shown.view, range);
    final plain = md.plainTextOf(lines);
    _copied = (plain: plain, lines: lines);
    return plain;
  }

  // Raw blocks.

  bool get _inRaw {
    final raw = _shown?.raw;
    final selection = composer.selection;
    return raw != null &&
        selection != null &&
        _ids.keyOf(selection.extent.nodeId) == raw.block;
  }

  /// [request] in the open raw block, edited as plain text there: Enter
  /// is a line break; Backspace at its start and Delete at its end do
  /// nothing. The owner then gets the block's text.
  void _rawEdit(EditRequest request) {
    final executor = _executor!;
    final command = switch (request) {
      InsertNewlineAtCaretRequest() || InsertSoftNewlineAtCaretRequest() =>
        _libraryCommand(InsertPlainTextAtCaretRequest('\n')),
      DeleteUpstreamAtBeginningOfNodeRequest() ||
      CombineParagraphsRequest() => null,
      _ => _libraryCommand(request),
    };
    if (command == null) return;
    executor.executeCommand(command);
    final selection = composer.selection;
    final node = selection == null
        ? null
        : _document.getNodeById(selection.extent.nodeId);
    if (selection == null || node is! TextNode) return;
    _gate.send(
      (now) => md.EditRaw(
        node.text.toPlainText(),
        base: (selection.base.nodePosition as TextNodePosition).offset,
        extent: (selection.extent.nodePosition as TextNodePosition).offset,
        revision: now.revision,
      ),
    );
  }

  EditCommand? _libraryCommand(EditRequest request) => _libraryHandlers
      .map((handler) => handler(editor, request))
      .nonNulls
      .firstOrNull;

  // Caret moves.

  /// At the end of each transaction without a content request: a caret
  /// the user moved goes to the owner. Compared in the library's terms,
  /// so a patch never reads as a move.
  void _onTransactionEnd(List<EditEvent> changes) {
    final content = _contentChanged;
    _contentChanged = false;
    if (content || !changes.any((change) => change is SelectionChangeEvent)) {
      return;
    }
    final shown = _shown;
    final selection = composer.selection;
    if (shown == null || selection == null) return;
    final raw = shown.raw;
    if (raw != null && _ids.keyOf(selection.extent.nodeId) == raw.block) {
      final (base, extent) = (
        selection.base.nodePosition,
        selection.extent.nodePosition,
      );
      if ((base, extent)
          case (
            TextNodePosition(offset: final base),
            TextNodePosition(offset: final extent),
          )
          when base != raw.base || extent != raw.extent) {
        _gate.send(
          (now) => md.RawCaretMoved(
            base: base,
            extent: extent,
            revision: now.revision,
          ),
        );
      }
      return;
    }
    if (selection == _positions.toLibrary(shown.selection, raw: raw)) return;
    if (_positions.toOwner(selection) case final moved?) {
      _gate.send((now) => md.CaretMoved(moved, revision: now.revision));
    }
  }

  // Patching.

  /// Makes the library's document show the owner's state: inside our
  /// command when one runs, else as its own transaction.
  void _patch() {
    final shown = _shown;
    if (shown == null) return;
    final looks = RowLooks(
      shown,
      showsChecked: _gate.showsChecked,
      addItems: _addItems,
      folded: _folded,
    ).looks;
    _applySplit(looks, shown);
    final nodes = [for (final look in looks) _target(_ids.of(look.key), look)];
    _ids.keepOnly({for (final look in looks) look.key});
    final selection = _positions.toLibrary(shown.selection, raw: shown.raw);
    switch (_executor) {
      case final executor?:
        executor.executeCommand(PatchCommand(nodes, selection: selection));
      case null:
        editor.execute([_PatchRequest(nodes, selection: selection)]);
    }
  }

  /// The node [id] showing [look].
  static TargetNode _target(String id, RowLook look) => (
    id: id,
    shows: (node) => lookOf(node) == look,
    build: () => libraryNodeOf(id, look),
  );

  /// After an Enter, the row above the caret shows in the node the caret
  /// was in, and the caret's row in the node the library made for it.
  void _applySplit(List<RowLook> looks, md.FormattedContent shown) {
    final split = _split;
    _split = null;
    if (split == null) return;
    final caret = switch (shown.selection) {
      md.TextSelection(:final extent) => extent.leaf,
      md.BlockSelection(:final block) => block,
    };
    final index = looks.indexWhere((look) => look.key == caret);
    if (index < 1) return;
    _ids.split(
      split.id,
      top: looks[index - 1].key,
      bottom: caret,
      newId: split.newId,
    );
  }

  void dispose() {
    _gate.removeListener(_patch);
    editor.dispose();
  }
}

/// The library's own request handlers.
final _libraryHandlers = defaultRequestHandlers.cast<EditRequestHandler>();

/// Patches the library's document; see [PatchCommand].
final class _PatchRequest implements EditRequest {
  const _PatchRequest(this.nodes, {required this.selection});

  final List<TargetNode> nodes;
  final DocumentSelection? selection;
}

/// Runs [action], which sends an owner input, as a library command: the
/// patch that follows runs in the same transaction.
final class _RunCommand extends EditCommand {
  const _RunCommand(this._adapter, this.action);

  final VisualAdapter _adapter;
  final void Function() action;

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.nonHistorical;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final outer = _adapter._executor;
    _adapter
      .._executor = executor
      .._contentChanged = true;
    try {
      action();
    } finally {
      _adapter._executor = outer;
    }
  }
}

/// A content request Visual edit doesn't take: nothing happens.
final class _Refused extends EditCommand {
  const _Refused();

  @override
  HistoryBehavior get historyBehavior => HistoryBehavior.nonHistorical;

  @override
  void execute(EditContext context, CommandExecutor executor) {}
}
