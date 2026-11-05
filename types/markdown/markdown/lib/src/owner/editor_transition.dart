import 'package:truce_core/truce_core.dart'
    show
        EditorBook,
        EditorNotice,
        EditorSteps,
        EffectId,
        SentText,
        OfferedUndo,
        ShownStep,
        Step,
        StepRun,
        TextChange,
        TextStep,
        TextSummary,
        Typing,
        UndoOffered,
        lineAt,
        lineStart,
        textChange,
        typingFrom;

import '../doc/doc_nodes.dart';
import '../doc/doc_tree.dart';
import '../doc/origin.dart';
import '../edit/clipboard_lines.dart';
import '../edit/commands/acted_on.dart';
import '../edit/commands/command.dart';
import '../edit/commands/links.dart' show linkHere;
import '../edit/commands/text_commands.dart' show ordered;
import '../edit/keys/key_map.dart';
import '../edit/selection.dart';
import '../edit/text_places.dart' show textAt;
import '../edit/typing_style.dart';
import '../print/printer.dart';
import '../summary/document_summary.dart';
import '../view/rows.dart';
import '../visible/formatting.dart';
import 'editor_contract.dart';
import 'editor_work.dart';
import 'history/markdown_step.dart';
import 'history/typing.dart';
import 'raw_closed.dart';
import 'reload.dart';

/// The editor owner's decision on [message] in [state], with its [work].
Step<EditorState, EditorWork, EditorEvent, EditorEffect> editorStep(
  EditorState state,
  EditorWork work,
  EditorMessage message,
) {
  return _Step(state, work).run(message);
}

/// One input's handling: the state as it changes and what it leads to.
final class _Step
    extends
        StepRun<
          EditorMessage,
          EditorState,
          EditorWork,
          EditorEvent,
          EditorEffect
        >
    with EditorSteps<MarkdownStep> {
  _Step(super.state, super.work);

  @override
  EditorBook<MarkdownStep> get book => work.book;

  @override
  set book(EditorBook<MarkdownStep> book) => work = work.copyWith(book: book);

  @override
  void notify(EditorNotice notice) => events.add(Notice(notice));

  @override
  void startTimer(EffectId id, Duration delay) =>
      effects.add(StartSaveTimer(id, delay));

  /// In Visual edit and Read, the summary is of the tree that printed the
  /// text; in Markdown edit, of the text, read only if asked.
  @override
  SentText get sent {
    final (:printed, :doc) = _printedFrom();
    return SentText(printed.text, switch (doc) {
      final doc? => DocumentSummary.ofTree(doc, maxLines: 0),
      null => DocumentSummary.of(printed.text, maxLines: 0),
    });
  }

  /// The tree read from [text] in Visual edit and Read; in Markdown edit,
  /// [text], read only if asked.
  @override
  TextSummary<Object?> summaryOfShown(String text) => switch (state.content) {
    FormattedContent(:final view) => DocumentSummary.ofTree(
      view.doc,
      maxLines: 0,
    ),
    MarkdownContent() => DocumentSummary.of(text, maxLines: 0),
  };

  /// Read shows the text kept.
  @override
  bool get sendsAtOnce => state.mode == EditMode.read;

  /// What the input's step did, if it is offered for undo right away.
  OfferedUndo? offered;

  /// Where the input's commands acted: the row the first acted at before
  /// it, and the row the last shows at after it.
  ({NodeId? before, NodeId? after})? _acted;

  @override
  void handle(EditorMessage message) {
    switch (message) {
      case SaveTimerFired(:final id):
        fired(id);
        _settleFlags();
      case final EditorInput input:
        _input(input);
    }
  }

  void _input(EditorInput input) {
    // An input on what no longer shows (e.g. a box tap whose wait ended
    // after a change elsewhere) is dropped.
    if (input case ShownInput(:final revision)
        when revision != state.revision) {
      return;
    }
    final (before, origin, rev) = (state, work.origin, book.rev);
    _handle(input);
    if (_byControl(input)) _removeCaret();
    switch (input) {
      case ShownInput() when book.rev != rev:
        final (step, typing) = _stepOf(input, before, origin);
        record(step, typing);
        if (offered case final what?) {
          notify(UndoOffered(book.history.latestId!, what));
        }
      case CaretMoved() ||
          RawCaretMoved() ||
          TextCaretMoved() ||
          CloseRawBlock():
        // Typing after a caret move starts a new step.
        endTypingRun();
      case _:
        break;
    }
    _settleFlags();
  }

  /// The edit [input] made from what showed [before], read from
  /// [origin], as an undo step, and the typing it was.
  (MarkdownStep, Typing?) _stepOf(
    EditorInput input,
    EditorState before,
    Origin origin,
  ) => switch ((before.content, state.content)) {
    (MarkdownContent(text: final was), MarkdownContent(:final text)) =>
      _textStep(input, textChange(was, text)),
    (final FormattedContent was, final FormattedContent now) => (
      TreeStep(
        ShownStep(
          TreeSide(was, origin, at: _acted?.before),
          TreeSide(now, work.origin, at: _acted?.after),
        ),
      ),
      typingOf(input, before, state),
    ),
    _ => throw StateError('an edit changed the mode'),
  };

  /// [change], made by [input] in Markdown edit, as an undo step, and the
  /// typing it was.
  static (MarkdownStep, Typing?) _textStep(
    EditorInput input,
    TextChange change,
  ) => (
    TextChangeStep(TextStep(change)),
    switch (input) {
      EditText(pasted: false) => typingFrom(#markdown, change),
      _ => null,
    },
  );

  /// Whether [input] comes from a control (a row's box, delete button,
  /// drag or swipe, a Done heading, a menu): it leaves no caret.
  static bool _byControl(EditorInput input) => switch (input) {
    Run(:final byControl) => byControl,
    ToggleItems() || SetCollapsed() || RemoveCaret() => true,
    _ => false,
  };

  /// No caret shows any more, an open raw block closed too; the next tap
  /// into text places one.
  void _removeCaret() {
    if (state.content case final FormattedContent shown
        when shown.selection != null || shown.raw != null) {
      final view = shown.raw == null ? shown.view : _closedRaw(null).view;
      _show(FormattedContent(view: view, selection: null));
    }
  }

  void _handle(EditorInput input) {
    switch ((input, state.content)) {
      case (Request(:final request), _):
        handleRequest(request);
      case (final ShownInput input, final FormattedContent shown)
          when state.mode == EditMode.visual:
        _visual(input, shown);
      case (EditText(:final text), MarkdownContent(text: final old))
          when text != old:
        _show(MarkdownContent(text));
        textChanged();
      case (SetMode(:final mode), _):
        _setMode(mode);
      case (SetCheckedItems(:final checkedItems), _):
        _setCheckedItems(checkedItems);
      case (
        SetCollapsed(:final list, :final collapsed),
        FormattedContent(view: ViewRows(:final doc, done: final done?)),
      ):
        _show(
          _formatted(
            view: ViewRows(
              doc,
              done: done.withCollapsed(list, collapsed: collapsed),
            ),
          ),
        );
      case _:
        break;
    }
  }

  // Visual edit.

  void _visual(ShownInput input, FormattedContent shown) {
    switch ((input, shown.raw)) {
      case (EditRaw(:final text, :final base, :final extent), final raw?):
        _show(
          _formatted(
            raw: RawRegion(raw.block, text, base: base, extent: extent),
          ),
        );
        if (text != raw.text) textChanged();
      case (RawCaretMoved(:final base, :final extent), final raw?):
        _show(
          _formatted(
            raw: RawRegion(raw.block, raw.text, base: base, extent: extent),
          ),
        );
      case (CaretMoved(:final selection), _):
        _show(_closedRaw(selection));
      case (CloseRawBlock(), _?):
        _show(_closedRaw(null));
      case (CloseRawBlock(), null):
        break;
      case (_, _?):
        // Any other input closes the raw block first.
        final closed = _closedRaw(shown.selection);
        _show(closed);
        _visual(input, closed);
      case (Pressed(:final key), null):
        _pressed(shown, key);
      case (Typed(:final text, :final over), null):
        _typed(shown, text, over);
      case (Run(command: Toggle()), null):
        assert(false, 'a box tap is a ToggleItem');
      case (
        Run(command: DeleteRange(selection: final TextSelection range)),
        null,
      ):
        _deleted(shown, range);
      case (Run(command: AddItem(:final list, at: AddAt.last)), null)
          when state.checkedItems == CheckedItems.moveToEnd:
        // Checked items stay at the end.
        _run(AddItem(list, at: AddAt.afterOpen));
      case (Run(:final command), null):
        _run(command);
      case (ToggleItems(:final items), null):
        _toggle(items);
      case (OpenRawBlock(:final block, :final atEnd), null):
        _openRaw(shown, block, atEnd: atEnd);
      case _:
        break;
    }
  }

  /// [key] acts at the caret; without one, it does nothing.
  void _pressed(FormattedContent shown, EditKey key) {
    final selection = shown.selection;
    if (selection == null) return;
    switch (keyAction(shown.view, selection, key)) {
      case RunCommand(:final command):
        _run(command);
      case OpenRaw(:final block, :final atEnd):
        _openRaw(shown, block, atEnd: atEnd);
      case ToggleTypingStyle(:final format):
        final caret = (selection as TextSelection).extent;
        final style = shown.typingStyle ?? typingStyleAt(shown.view.doc, caret);
        _show(
          _formatted(
            typingStyle: style.withFormat(format, on: !style.has(format)),
          ),
        );
      case OpenLinkDialog():
        if (selection case final TextSelection range) {
          events.add(_askLink(shown.view, range));
        }
      case Consumed():
        break;
    }
  }

  /// The link dialog on [range]: on a link, the whole of it, to edit;
  /// else the text selected, to link.
  static AskLink _askLink(ViewRows view, TextSelection range) =>
      switch (linkHere(view, range)) {
        (:final range, :final text, :final url, :final removable) => AskLink(
          range,
          text: text,
          url: url,
          removable: removable,
        ),
        null => AskLink(range, text: plainTextOf(copiedLines(view, range))),
      };

  /// [text] typed over [over]: over a block selected whole, the text
  /// takes its place, plain.
  void _typed(FormattedContent shown, String text, Selection over) =>
      switch (over) {
        final TextSelection range => _typedText(shown, text, range),
        BlockSelection() ||
        BlockCaret() => _run(Paste(over, plainLines(text, .plain))),
      };

  /// [text] typed over [range]: the typing style holds only at the
  /// shown caret.
  void _typedText(FormattedContent shown, String text, TextSelection range) {
    final at = range.extent;
    final style =
        (range == shown.selection ? shown.typingStyle : null) ??
        typingStyleAt(shown.view.doc, at);
    final lines = plainLines(text, style);
    _run(switch (range) {
      _ when lines.length > 1 => Paste(range, lines),
      _ when range.isCaret => InsertText(at, text, style),
      _ when range.base.leaf == range.extent.leaf => ReplaceText(range, text),
      _ => Paste(range, lines),
    });
  }

  /// [range] deleted; typing right there goes on in the formatting of
  /// the first character deleted, as typing over a selection does.
  void _deleted(FormattedContent shown, TextSelection range) {
    final (start, end) = ordered(shown.view, range);
    _run(DeleteRange(range));
    if (start.leaf != end.leaf || start.offset == end.offset) return;
    final deleted = textAt(
      shown.view.doc,
      start.leaf,
    ).formattingAt(start.offset);
    _show(_formatted(typingStyle: deleted));
  }

  /// [command] run on what shows; a changed document is a text change.
  /// One that holds the same as before (e.g. the link dialog confirmed
  /// unchanged, a keyboard putting back the word it typed) is no change,
  /// so no undo step and no save: the document stays as it was.
  void _run(Command command) {
    final shown = state.content as FormattedContent;
    final before = shown.view.doc;
    final edited = run(shown.view, command);
    final doc = edited.doc.holdsSameAs(before) ? before : edited.doc;
    if (!identical(doc, before)) {
      final acted = actedOn(shown.view, command);
      _acted = (
        before: _acted == null ? acted : _acted!.before,
        after: shownAfter(shown.view, edited, acted),
      );
    }
    _show(
      FormattedContent(
        view: ViewRows(doc, done: shown.view.done),
        selection: edited.selection,
      ),
    );
    if (identical(doc, before)) return;
    textChanged();
    if (_removes(command, before, doc)) offered = OfferedUndo.removal;
  }

  /// Whether [command] removed what an undo is offered for: items by the
  /// delete button or the menu, a block without text (but a divider,
  /// which goes as one character), code, or more than one leaf. An
  /// emptied code block goes like an emptied paragraph.
  bool _removes(Command command, DocTree before, DocTree after) {
    if (command is DeleteItem || command is ClearChecked) return true;
    final removed = leavesIn(before.root)
        .where((leaf) => after.nodeOf(leaf.id) == null)
        .toList();
    return removed.length > 1 ||
        removed.any(
          (leaf) => switch (leaf) {
            TextNode() || DividerNode() => false,
            CodeNode(:final code) => code.isNotEmpty,
            _ => true,
          },
        );
  }

  // Undo and redo.

  @override
  void undo(MarkdownStep step) => switch (step) {
    TreeStep(:final sides) => _showSide(sides.before),
    TextChangeStep(:final step) => _showText(step.undoneIn),
  };

  @override
  void redo(MarkdownStep step) => switch (step) {
    TreeStep(:final sides) => _showSide(sides.after),
    TextChangeStep(:final step) => _showText(step.redoneIn),
  };

  /// What Visual edit showed at [side] shows again: in Visual edit, its
  /// tree with its row shown (its caret only while one shows: after a
  /// control, none comes back); in Markdown edit, its print, the caret at
  /// its row's start, and Visual edit comes back to it.
  void _showSide(TreeSide side) {
    switch (state.content) {
      case FormattedContent(:final view, :final selection):
        work = work.copyWith(origin: side.origin);
        _show(
          FormattedContent(
            view: _rows(side.doc, view.done, state.checkedItems),
            selection: selection == null ? null : side.selection,
          ),
        );
        _showRow(side.row);
      case MarkdownContent():
        final printed = side.printed;
        work = work.copyWith(
          left: (
            view: ViewRows(side.doc),
            selection: side.selection,
            printed: printed,
          ),
        );
        final line = printed.lines[side.row]?.first ?? 0;
        _show(
          MarkdownContent(printed.text, caret: lineStart(printed.text, line)),
        );
    }
  }

  /// The text that shows as [changed] changes it: in Markdown edit, the
  /// caret at the change; in Visual edit, the print changed, read anew,
  /// the row on the changed line shown.
  void _showText(({String text, int caret}) Function(String text) changed) {
    switch (state.content) {
      case MarkdownContent(text: final shown):
        final (:text, :caret) = changed(shown);
        _show(MarkdownContent(text, caret: caret));
      case FormattedContent():
        final printed = _printed();
        final (:text, :caret) = changed(printed.text);
        final next = loaded(text);
        _reloadTo(next, printed: printed);
        final view = (state.content as FormattedContent).view;
        _showRow(leafOnLine(next.printed, lineAt(text, caret), view));
    }
  }

  /// Visual edit shows [leaf]'s row, if one is known.
  void _showRow(NodeId? leaf) {
    if (leaf != null) events.add(ShowRow(leaf));
  }

  @override
  MarkdownStep replaceText(String text) {
    switch (state.content) {
      case MarkdownContent(text: final old):
        _show(MarkdownContent(text, caret: 0));
        return TextChangeStep(TextStep(textChange(old, text)));
      case final FormattedContent before:
        final origin = work.origin;
        final next = loaded(text);
        work = work.copyWith(origin: next.origin);
        _show(_fresh(next.doc));
        return TreeStep(
          ShownStep(
            TreeSide(before, origin),
            TreeSide(state.content as FormattedContent, next.origin),
          ),
        );
    }
  }

  /// [items]' boxes toggled in order; with "Move to end", the checked
  /// ones move together.
  void _toggle(List<NodeId> items) {
    for (final item in items) {
      _run(Toggle(item));
    }
    if (state.checkedItems != CheckedItems.moveToEnd) return;
    final after = state.content as FormattedContent;
    final checked = [
      for (final item in items)
        if (after.view.doc.nodeOf(item) case ItemNode(checked: true)) item,
    ];
    if (checked.isNotEmpty) {
      _run(MoveToEnd(items: checked));
    }
  }

  // Raw blocks.

  void _openRaw(FormattedContent shown, NodeId block, {required bool atEnd}) {
    if (shown.view.doc.nodeOf(block) case RawLeaf(:final raw)) {
      final caret = atEnd ? raw.length : 0;
      _show(
        _formatted(
          raw: RawRegion(block, raw, base: caret, extent: caret),
        ),
      );
    }
  }

  /// What shows once the open raw block, if one is, takes what was typed
  /// in it (which the text sent holds already), [selection] where it
  /// stays.
  FormattedContent _closedRaw(Selection? selection) {
    final shown = state.content as FormattedContent;
    final closed = rawClosed(shown, selection);
    return FormattedContent(
      view: ViewRows(closed.doc, done: shown.view.done),
      selection: closed.selection,
    );
  }

  // View state.

  void _setMode(EditMode mode) {
    switch ((state.content, mode)) {
      case (FormattedContent(:final view, :final selection), EditMode.markdown):
        final printed = _printed();
        work = work.copyWith(
          left: (view: view, selection: selection, printed: printed),
        );
        _show(MarkdownContent(printed.text), mode: mode);
      case (MarkdownContent(:final text), EditMode.visual || EditMode.read):
        _show(state.content, mode: mode);
        reload(text);
        work = work.copyWith(left: null);
        if (mode == EditMode.read) send();
      case (FormattedContent(:final selection), _):
        _show(_closedRaw(selection), mode: mode);
        // Read shows the text as sent.
        if (mode == EditMode.read) send();
      case (MarkdownContent(), _):
        break;
    }
  }

  /// Checked items show as [checkedItems] says; nothing moves.
  void _setCheckedItems(CheckedItems checkedItems) {
    if (state.content case FormattedContent(:final selection, :final view)) {
      final closed = _closedRaw(selection);
      state = _state(
        content: FormattedContent(
          view: _rows(closed.view.doc, view.done, checkedItems),
          selection: closed.selection,
        ),
        checkedItems: checkedItems,
      );
    } else {
      state = _state(checkedItems: checkedItems);
    }
  }

  // Saving.

  /// What the file says once the text is sent: the document printed,
  /// with the open raw block as typed.
  PrintedMarkdown _printed() => _printedFrom().printed;

  /// [_printed], and the doc tree that printed it (none in Markdown edit,
  /// which edits the text itself).
  ({PrintedMarkdown printed, DocTree? doc}) _printedFrom() {
    switch (state.content) {
      case FormattedContent(:final selection):
        final doc = _closedRaw(selection).view.doc;
        return (printed: printMarkdown(doc, work.origin), doc: doc);
      case MarkdownContent(:final text):
        return (printed: (text: text, lines: const {}), doc: null);
    }
  }

  // Changes from the file owner.

  /// [text] shows instead, read anew: the selection and collapsed Done
  /// sections follow their lines, and an open raw block whose text the
  /// change kept stays open.
  @override
  void reload(String text) => state.mode == EditMode.markdown
      ? _show(MarkdownContent(text))
      : _reloadTo(loaded(text));

  /// [next] shows instead, as [reload] says, in Visual edit or Read;
  /// [printed] is the print of what shows, if known.
  void _reloadTo(ReadDocument next, {PrintedMarkdown? printed}) {
    final content = switch (state.content) {
      FormattedContent(:final view, :final selection, :final raw) => _mapped(
        (view: view, selection: selection, printed: printed ?? _printed()),
        raw,
        next,
      ),
      MarkdownContent() => switch (work.left) {
        final left? => _mapped(left, null, next),
        null => _fresh(next.doc),
      },
    };
    work = work.copyWith(origin: next.origin);
    _show(content);
  }

  /// What showed [before], with [raw] open, as it falls in [next].
  FormattedContent _mapped(Left before, RawRegion? raw, ReadDocument next) {
    final map = ReloadMap(before.printed, next);
    final done = switch (before.view.done) {
      final done? => DoneSections(
        collapsed: map.lists(done.collapsed, before.view.doc),
      ),
      null => null,
    };
    final view = _rows(next.doc, done, state.checkedItems);
    return FormattedContent(
      view: view,
      selection: map.selection(before.selection, view),
      raw: switch (raw) {
        final raw? => _reopened(raw, map.leafOf(raw.block, view), view),
        null => null,
      },
    );
  }

  /// [doc] shown anew, without a caret.
  FormattedContent _fresh(DocTree doc) => FormattedContent(
    view: _rows(doc, null, state.checkedItems),
    selection: null,
  );

  /// [raw] open again on [block] in [view], if that holds its text.
  RawRegion? _reopened(RawRegion raw, NodeId? block, ViewRows view) =>
      switch (block == null ? null : view.doc.nodeOf(block)) {
        RawLeaf(raw: final now, :final id) when now == raw.text => RawRegion(
          id,
          raw.text,
          base: raw.base,
          extent: raw.extent,
        ),
        _ => null,
      };

  // State.

  /// [doc] in rows with checked items as [checkedItems] says, Done
  /// sections collapsed as [done] has them.
  ViewRows _rows(DocTree doc, DoneSections? done, CheckedItems checkedItems) =>
      ViewRows(
        doc,
        done: checkedItems == CheckedItems.doneSection
            ? done ?? DoneSections()
            : null,
      );

  /// What shows now with [view], [typingStyle] or [raw] changed.
  FormattedContent _formatted({
    ViewRows? view,
    Formatting? typingStyle,
    RawRegion? raw,
  }) {
    final shown = state.content as FormattedContent;
    return FormattedContent(
      view: view ?? shown.view,
      selection: shown.selection,
      typingStyle: typingStyle ?? shown.typingStyle,
      raw: raw ?? shown.raw,
    );
  }

  /// [content] shows, in [mode] if given.
  void _show(EditorContent content, {EditMode? mode}) =>
      state = _state(content: content, mode: mode);

  /// The state with what is given changed: what shows changed, so its
  /// revision moves on.
  EditorState _state({
    EditorContent? content,
    EditMode? mode,
    CheckedItems? checkedItems,
  }) => EditorState(
    content: content ?? state.content,
    mode: mode ?? state.mode,
    checkedItems: checkedItems ?? state.checkedItems,
    revision: state.revision + 1,
    status: book.status,
  );

  /// The state telling whether edits are only in memory and what undo
  /// and redo can do; what shows is the same.
  void _settleFlags() {
    final status = book.status;
    if (state.status == status) return;
    state = EditorState(
      content: state.content,
      mode: state.mode,
      checkedItems: state.checkedItems,
      revision: state.revision,
      status: status,
    );
  }
}
