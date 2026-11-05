import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart' show unchangedEnds;
import 'package:truce_markdown/truce_markdown.dart' as md;
import 'package:truce_markdown/truce_markdown.dart'
    show AddItemPlace, BlockLook, RawTextLook, RowLook, RowLooks, TextLook;

import '../../editor_gate.dart';
import '../../library/document_patch.dart';
import '../../library/own_clipboard.dart';
import 'library_nodes.dart';
import 'node_ids.dart';
import 'positions.dart';

/// Connects the library's [editor] to the editor owner behind [_gate].
/// Each library request that would change content becomes one owner
/// input carrying its own range (never a diff of the library's text);
/// a transaction that only moved the selection becomes a caret move.
/// After every change of the owner's state, the library's document is
/// patched to show it: only the range of rows whose looks changed is
/// patched, and there only rows whose look changed become new nodes.
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

  /// The looks the library's document shows, one per node, in order.
  List<RowLook> _looks = const [];

  Document get document => _document;

  /// The library node [leaf]'s row shows in; `null` if it doesn't show.
  String? nodeShowing(md.NodeId leaf) => _ids.find(leaf);

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

  /// A tap at [position]: on a divider, the caret goes right after it,
  /// as after one character; whether there was one.
  bool caretAfterDividerAt(DocumentPosition position) {
    final node = _document.getNodeById(position.nodeId);
    if (node == null) return false;
    if (lookOf(node) case BlockLook(leaf: md.DividerNode(:final id))) {
      _gate.send(
        (now) => md.CaretMoved(md.BlockCaret(id), revision: now.revision),
      );
      return true;
    }
    return false;
  }

  // Library requests.

  /// Our command for [request]: an owner input for a content request,
  /// `null` for a selection or composer request (the library's own
  /// handlers do those), a refusal for any other.
  EditCommand? _handle(Editor editor, EditRequest request) => switch (request) {
    _PatchRequest(:final nodes, :final start, :final count, :final selection) =>
      PatchCommand(
        nodes,
        start: start,
        count: count,
        selection: selection,
        byUser: _gate.fromUser,
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
    PasteRequest(:final text) => _paste(text),
    _ => null,
  };

  md.EditorInput? Function(md.EditorState) _typed(
    String text, {
    DocumentSelection? over,
  }) {
    final selection = _actedOn(over ?? composer.selection);
    return (now) => switch (selection) {
      final selection? => md.Typed(
        text,
        over: selection,
        revision: now.revision,
      ),
      null => null,
    };
  }

  md.EditorInput? Function(md.EditorState) _deleteRange(
    DocumentSelection? over,
  ) {
    final selection = _actedOn(over);
    return (now) => switch (selection) {
      final selection? => md.Run(
        md.DeleteRange(selection),
        revision: now.revision,
      ),
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

  /// Text from the clipboard over the selection, as one paste: the
  /// fragment copied here last, with its styles, while the clipboard
  /// still holds its text.
  md.EditorInput? Function(md.EditorState) _paste(String text) {
    final selection = _actedOn(composer.selection);
    final copied = _copied;
    return (now) => switch ((selection, copied)) {
      (final selection?, (:final plain, :final lines)) when plain == text =>
        md.Run(md.Paste(selection, lines), revision: now.revision),
      (final selection?, _) => md.Typed(
        text,
        over: selection,
        pasted: true,
        revision: now.revision,
      ),
      (null, _) => null,
    };
  }

  /// The owner's selection a request over the library's [selection] acts
  /// on (see [Positions.actedOn]).
  md.Selection? _actedOn(DocumentSelection? selection) =>
      switch ((_shown, selection)) {
        (final shown?, final selection?) => _positions.actedOn(
          selection,
          shown: shown.selection,
          raw: shown.raw,
        ),
        _ => null,
      };

  // Keys and actions.

  /// [text] pasted over the selection, as one edit.
  void paste(String text) => editor.execute([PasteRequest(text)]);

  /// [key] pressed: the toolbar or a keyboard shortcut.
  void press(md.EditKey key) =>
      _gate.send((now) => md.Pressed(key, revision: now.revision));

  /// Whether the selection is wholly in an open raw block, edited as
  /// plain text.
  bool get inRaw => _inRaw;

  /// Whether an input method is composing text: keys go to it.
  bool get composing => composer.composingRegion.value != null;

  /// Removes the selected text, after [_copySelection].
  void _deleteSelection() => _gate.send(
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

  /// Visual edit's own copy: [_copySelection], then [_deleteSelection]
  /// for a cut.
  OwnCopy get ownCopy => (text: _copySelection, remove: _deleteSelection);

  /// The selected text as lines with their styles, and as the plain text
  /// for the clipboard; remembered for a paste here.
  String? _copySelection() {
    final (shown, range) = (_shown, selectedRange);
    if (shown == null || range == null || range.isCaret) return null;
    final lines = md.copiedLines(shown.view, range);
    final plain = md.plainTextOf(lines);
    _copied = (plain: plain, lines: lines);
    return plain;
  }

  // Raw blocks.

  bool get _inRaw => switch ((_shown?.raw, composer.selection)) {
    (final raw?, final selection?) => _isWithin(raw, selection),
    _ => false,
  };

  /// Whether both ends of [selection] are in the open [raw] block.
  bool _isWithin(md.RawRegion raw, DocumentSelection selection) => [
    selection.base,
    selection.extent,
  ].every((end) => _ids.keyOf(end.nodeId) == RawTextLook.keyOf(raw.block));

  /// [request] in the open raw block, edited as plain text there: Enter
  /// is a line break; Backspace at its start and Delete at its end do
  /// nothing. The owner then gets the block's text.
  void _rawEdit(EditRequest request) {
    final executor = _executor!;
    final commands = switch (request) {
      InsertNewlineAtCaretRequest() || InsertSoftNewlineAtCaretRequest() => [
        ?_libraryCommand(InsertPlainTextAtCaretRequest('\n')),
      ],
      DeleteUpstreamAtBeginningOfNodeRequest() ||
      CombineParagraphsRequest() => <EditCommand>[],
      PasteRequest(:final text) => [
        for (final request in plainPasteRequests(text, composer.selection))
          ?_libraryCommand(request),
      ],
      _ => [?_libraryCommand(request)],
    };
    if (commands.isEmpty) return;
    commands.forEach(executor.executeCommand);
    final selection = composer.selection;
    final node = selection == null
        ? null
        : _document.getNodeById(selection.extent.nodeId);
    if (selection == null || node is! TextNode) return;
    _gate.send(
      (now) => md.EditRaw(
        node.text.toPlainText(),
        pasted: request is PasteRequest,
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
    if (raw != null && _isWithin(raw, selection)) {
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
    final was = _positions.toLibrary(shown.selection, raw: raw);
    if (selection == was) return;
    if (_positions.toOwner(selection, was: was) case final moved?) {
      _gate.send((now) => md.CaretMoved(moved, revision: now.revision));
    }
  }

  // Patching.

  /// Makes the library's document show the owner's state, inside our
  /// command when one runs, else as its own transaction: the rows between
  /// those whose looks stayed at the start and end are patched.
  void _patch() {
    final shown = _shown;
    if (shown == null) return;
    final looks = RowLooks(
      shown.view,
      selected: switch (shown.selection) {
        md.BlockSelection(:final block) => block,
        _ => null,
      },
      raw: switch (shown.raw) {
        md.RawRegion(:final block, :final text) => (block: block, text: text),
        null => null,
      },
      waiting: _gate.waiting,
      addItems: _addItems,
      folded: _folded,
    ).looks;
    final same = unchangedEnds(_looks, looks);
    final split = _applySplit(looks, shown);
    final start = min(same.start, split?.top ?? same.start);
    final end = min(same.end, looks.length - 1 - (split?.bottom ?? -1));
    final count = _looks.length - start - end;
    final range = looks.sublist(start, looks.length - end);
    _ids.forget(
      _looks
          .sublist(start, start + count)
          .map((look) => look.key)
          .toSet()
          .difference({for (final look in range) look.key}),
    );
    final nodes = [for (final look in range) _target(_ids.of(look.key), look)];
    _looks = looks;
    final selection = _positions.toLibrary(shown.selection, raw: shown.raw);
    switch (_executor) {
      case final executor?:
        executor.executeCommand(
          PatchCommand(
            nodes,
            start: start,
            count: count,
            selection: selection,
            byUser: _gate.fromUser,
          ),
        );
      case null:
        editor.execute([
          _PatchRequest(
            nodes,
            start: start,
            count: count,
            selection: selection,
          ),
        ]);
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
  /// Also where the owner split nothing (an empty item taken out of its
  /// list): the rows then only change nodes, which shows the same, and
  /// the input method finds the caret in the new node, as it expects
  /// after every Enter. The indexes of the two rows, which the patch must
  /// take in; `null` if there was no split.
  ({int top, int bottom})? _applySplit(
    List<RowLook> looks,
    md.FormattedContent shown,
  ) {
    final split = _split;
    _split = null;
    if (split == null) return null;
    final caret = switch (shown.selection) {
      md.TextSelection(:final extent) => extent.leaf,
      md.BlockSelection(:final block) || md.BlockCaret(:final block) => block,
      null => null,
    };
    final index = looks.indexWhere((look) => look.key == caret);
    if (index < 1) return null;
    _ids.split(
      split.id,
      top: looks[index - 1].key,
      bottom: caret,
      newId: split.newId,
    );
    return (top: index - 1, bottom: index);
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
  const _PatchRequest(
    this.nodes, {
    required this.start,
    required this.count,
    required this.selection,
  });

  final List<TargetNode> nodes;
  final int start;
  final int count;
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
